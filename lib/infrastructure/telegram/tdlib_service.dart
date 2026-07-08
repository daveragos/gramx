import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:handy_tdlib/handy_tdlib.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gramx/core/config/app_config.dart';

/// Service wrapper around native TDLib (handy_tdlib) using a background Isolate.
class TdlibService {
  int? _clientId;
  Isolate? _updatesIsolate;
  final _updatesController = StreamController<td.TdObject>.broadcast();
  final _invokesController = StreamController<Map<String, dynamic>>.broadcast();
  final _authEventController = StreamController<td.AuthorizationState>.broadcast();

  // Ports for isolate communication
  ReceivePort? _updatesReceivePort;

  TdlibService(Ref ref);

  /// Stream of all incoming TDLib updates (excluding invoke results).
  Stream<td.TdObject> get updatesStream => _updatesController.stream;

  /// Stream of authorization state updates.
  Stream<td.AuthorizationState> get authStateStream => _authEventController.stream;

  /// Retrieves the active client ID.
  int? get clientId => _clientId;

  /// Initialize TDLib and spawn the updates listener isolate.
  Future<void> initialize() async {
    if (_clientId != null) return; // already initialized

    // Create client ID (must run on the main/invoker thread)
    _clientId = TdPlugin.instance.tdCreateClientId();
    debugPrint('[TDLib] Created Client ID: $_clientId');

    // Setup ports
    _updatesReceivePort = ReceivePort();
    
    // Spawn background isolate to run the blocking tdReceive loop
    _updatesIsolate = await Isolate.spawn(
      _updatesIsolateLoop,
      _UpdatesIsolateParams(
        sendPort: _updatesReceivePort!.sendPort,
      ),
    );

    // Listen for updates from the isolate
    _updatesReceivePort!.listen((message) {
      if (message is String) {
        try {
          final map = jsonDecode(message) as Map<String, dynamic>;
          if (map.containsKey('@extra')) {
            // This is a response to an invocation
            _invokesController.add(map);
          } else {
            // This is a general update from Telegram
            final object = convertJsonToObject(message);
            if (object != null) {
              _handleIncomingUpdate(object);
            }
          }
        } catch (e) {
          debugPrint('[TDLib] JSON decode error on update: $e');
        }
      }
    });

    // Start authorization parameters setting
    updatesStream.listen((event) {
      if (event is td.UpdateAuthorizationState) {
        _authEventController.add(event.authorizationState);
        _handleAuthorizationState(event.authorizationState);
      }
    });
  }

  /// Send a TDLib request and return the deserialized response.
  Future<td.TdObject> sendRequest(td.TdFunction function, {int? extraId}) async {
    if (_clientId == null) {
      throw Exception('TDLib client not initialized.');
    }

    final completer = Completer<td.TdObject>();
    final extra = extraId ?? DateTime.now().microsecondsSinceEpoch;

    // Listen to updates to find the response matching this request's extra id
    late StreamSubscription sub;
    sub = _invokesController.stream.listen((map) {
      if (map['@extra'] == extra) {
        sub.cancel();
        final object = convertJsonToObject(jsonEncode(map));
        if (object != null) {
          if (object is td.TdError) {
            completer.completeError(Exception(object.message));
          } else {
            completer.complete(object);
          }
        } else {
          completer.completeError(Exception('Failed to deserialize response.'));
        }
      }
    });

    final map = function.toJson();
    map['@extra'] = extra;
    final json = jsonEncode(map);
    
    TdPlugin.instance.tdSend(_clientId!, json);

    return completer.future;
  }

  void _handleIncomingUpdate(td.TdObject object) {
    _updatesController.add(object);
  }

  /// Handles TDLib parameter requests and auth steps automatically.
  Future<void> _handleAuthorizationState(td.AuthorizationState state) async {
    debugPrint('[TDLib] Auth State Changed: ${state.runtimeType}');

    if (state is td.AuthorizationStateWaitTdlibParameters) {
      final appDir = await getApplicationDocumentsDirectory();
      final databaseDir = '${appDir.path}/tdlib/db';
      final filesDir = '${appDir.path}/tdlib/files';

      final request = td.SetTdlibParameters(
        useTestDc: false,
        databaseDirectory: databaseDir,
        filesDirectory: filesDir,
        databaseEncryptionKey: '',
        useFileDatabase: true,
        useChatInfoDatabase: true,
        useMessageDatabase: true,
        useSecretChats: false,
        apiId: AppConfig.apiId,
        apiHash: AppConfig.apiHash,
        systemLanguageCode: 'en',
        deviceModel: 'Android',
        systemVersion: 'Android 10',
        applicationVersion: '1.0.0',
      );

      final json = jsonEncode(request.toJson());
      TdPlugin.instance.tdSend(_clientId!, json);
      debugPrint('[TDLib] Sent TdlibParameters');
    }
  }

  /// Close TDLib client and kill isolate.
  Future<void> dispose() async {
    if (_updatesIsolate != null) {
      _updatesIsolate!.kill(priority: Isolate.beforeNextEvent);
      _updatesIsolate = null;
    }
    _updatesReceivePort?.close();
    await _updatesController.close();
    await _invokesController.close();
    await _authEventController.close();
    _clientId = null;
  }
}

/// Parameters passed to the background updates isolate.
class _UpdatesIsolateParams {
  final SendPort sendPort;

  _UpdatesIsolateParams({
    required this.sendPort,
  });
}

/// Background loop running in the spawned Isolate.
/// It continuously calls tdReceive and sends raw JSON strings to the main port.
void _updatesIsolateLoop(_UpdatesIsolateParams params) {
  debugPrint('[TDLib Isolate] Starting receive loop');
  while (true) {
    // tdReceive is blocking with a 1-second timeout
    final String? response = TdPlugin.instance.tdReceive(1.0);
    if (response != null && response.isNotEmpty) {
      params.sendPort.send(response);
    }
  }
}

/// Riverpod provider for TdlibService.
final tdlibServiceProvider = Provider<TdlibService>((ref) {
  final service = TdlibService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
