import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:handy_tdlib/handy_tdlib.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gramx/core/config/app_config.dart';

/// Service wrapper around native TDLib (handy_tdlib).
class TdlibService {
  int? _clientId;
  Future<void>? _initializeMemoizer;
  Timer? _pollTimer;

  final _updatesController = StreamController<td.TdObject>.broadcast();
  final _invokesController = StreamController<Map<String, dynamic>>.broadcast();
  final _authEventController =
      StreamController<td.AuthorizationState>.broadcast();
  final _statusMessageController = StreamController<String>.broadcast();
  final _fileUpdateController = StreamController<td.UpdateFile>.broadcast();

  td.AuthorizationState? _currentAuthState;
  String _lastStatusMessage = 'Initializing TDLib...';

  TdlibService(Ref ref);

  /// Stream of all incoming TDLib updates (excluding invoke results).
  Stream<td.TdObject> get updatesStream {
    if (_clientId == null) {
      initialize().catchError((e) {
        debugPrint('[TDLib] Lazy initialization error on updatesStream: $e');
      });
    }
    return _updatesController.stream;
  }

  /// Stream of status messages during initialization.
  Stream<String> get statusMessageStream => _statusMessageController.stream;
  String get lastStatusMessage => _lastStatusMessage;

  /// Stream of file download updates from TDLib.
  Stream<td.UpdateFile> get fileUpdates => _fileUpdateController.stream;

  /// Stream of authorization state updates.
  Stream<td.AuthorizationState> get authStateStream {
    if (_clientId == null) {
      initialize().catchError((e) {
        debugPrint('[TDLib] Lazy initialization error on authStateStream: $e');
      });
    }
    final cached = _currentAuthState;
    if (cached != null) {
      late StreamController<td.AuthorizationState> controller;
      StreamSubscription<td.AuthorizationState>? sub;
      controller = StreamController<td.AuthorizationState>(
        onListen: () {
          controller.add(cached);
          sub = _authEventController.stream.listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
          );
        },
        onCancel: () {
          sub?.cancel();
          controller.close();
        },
      );
      return controller.stream;
    }
    return _authEventController.stream;
  }

  td.AuthorizationState? get currentAuthState => _currentAuthState;
  int? get clientId => _clientId;

  void _updateStatus(String msg) {
    _lastStatusMessage = msg;
    _statusMessageController.add(msg);
    debugPrint('[TDLib Status] $msg');
  }

  /// Initialize TDLib and start non-blocking update polling.
  Future<void> initialize() async {
    if (_initializeMemoizer != null) {
      return _initializeMemoizer;
    }
    final completer = Completer<void>();
    _initializeMemoizer = completer.future;

    try {
      if (_clientId != null) {
        completer.complete();
        return;
      }

      _updateStatus('Loading TDLib binary...');
      await TdPlugin.initialize();

      _clientId = TdPlugin.instance.tdCreateClientId();
      _updateStatus('TDLib client initialized (ID: $_clientId)');

      // Start non-blocking polling
      _startPolling();

      // Query current authorization state immediately to seed the service
      try {
        _updateStatus('Connecting to Telegram network...');
        final stateRes = await sendRequest(const td.GetAuthorizationState());
        if (stateRes is td.AuthorizationState) {
          _handleIncomingUpdate(td.UpdateAuthorizationState(authorizationState: stateRes));
        }
      } catch (e) {
        debugPrint('[TDLib] Initial GetAuthorizationState query note: $e');
      }

      completer.complete();
    } catch (e, stack) {
      _initializeMemoizer = null; // Allow retry on failure
      _updateStatus('TDLib initialization failed: $e');
      completer.completeError(e, stack);
      rethrow;
    }
  }

  /// Non-blocking polling loop (drains pending updates every 50ms)
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _drainUpdates();
    });
  }

  final Map<String, Completer<td.TdObject>> _pendingRequests = {};

  /// Drain all pending updates from native queue using tdReceive(0)
  void _drainUpdates() {
    for (int i = 0; i < 100; i++) {
      final String? response = TdPlugin.instance.tdReceive(0);
      if (response == null || response.isEmpty) return;

      try {
        final map = jsonDecode(response) as Map<String, dynamic>;
        if (map.containsKey('@extra')) {
          final extra = map['@extra']?.toString();
          final completer = extra != null ? _pendingRequests.remove(extra) : null;
          if (completer != null) {
            final object = convertJsonToObject(jsonEncode(map));
            if (object != null) {
              if (object is td.TdError) {
                completer.completeError(Exception(object.message));
              } else {
                completer.complete(object);
              }
            } else {
              completer.completeError(Exception('Failed to deserialize TDLib response.'));
            }
          } else {
            _invokesController.add(map);
          }
        } else {
          final object = convertJsonToObject(response);
          if (object != null) {
            _handleIncomingUpdate(object);
          }
        }
      } catch (e) {
        debugPrint('[TDLib] JSON decode error on update: $e');
      }
    }
  }

  /// Send a TDLib request and await its typed response.
  Future<td.TdObject> sendRequest(
    td.TdFunction function, {
    String? extraId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_clientId == null) {
      await initialize();
    }

    final completer = Completer<td.TdObject>();
    final extra = extraId ?? DateTime.now().microsecondsSinceEpoch.toString();
    _pendingRequests[extra] = completer;

    final map = function.toJson();
    map['@extra'] = extra;
    final json = jsonEncode(map);

    TdPlugin.instance.tdSend(_clientId!, json);

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingRequests.remove(extra);
        throw TimeoutException('TDLib request ${function.runtimeType} timed out.');
      },
    );
  }

  List<td.ChatFolderInfo> _chatFolders = [];
  List<td.ChatFolderInfo> get chatFolders => _chatFolders;

  void _handleIncomingUpdate(td.TdObject object) {
    if (object is td.UpdateAuthorizationState) {
      _currentAuthState = object.authorizationState;
      debugPrint('[TDLib Update] UpdateAuthorizationState -> ${object.authorizationState.runtimeType}');
      _authEventController.add(object.authorizationState);
      _handleAuthorizationState(object.authorizationState);
    } else if (object is td.UpdateChatFolders) {
      _chatFolders = object.chatFolders;
    } else if (object is td.TdError) {
      debugPrint('[TDLib Global Error] ${object.code}: ${object.message}');
    }
    // Only broadcast completed file updates to UI stream listeners
    if (object is td.UpdateFile && object.file.local.isDownloadingCompleted) {
      _fileUpdateController.add(object);
    }
    _updatesController.add(object);
  }

  /// Handles TDLib parameter requests and automated auth transitions.
  Future<void> _handleAuthorizationState(td.AuthorizationState state) async {
    debugPrint('[TDLib] State handling: ${state.runtimeType}');

    if (state is td.AuthorizationStateWaitTdlibParameters) {
      _updateStatus('Configuring Telegram parameters...');
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final databaseDir = '${appDir.path}/tdlib/db';
        final filesDir = '${appDir.path}/tdlib/files';

        await Directory(databaseDir).create(recursive: true);
        await Directory(filesDir).create(recursive: true);

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
          deviceModel: 'gramX Client',
          systemVersion: 'Android/iOS',
          applicationVersion: '1.0.0',
        );

        final res = await sendRequest(request);
        if (res is td.TdError) {
          _updateStatus('Parameter error: ${res.message}');
        } else {
          _updateStatus('Parameters accepted by Telegram.');
        }
      } catch (e) {
        _updateStatus('Failed to set TDLib parameters: $e');
        debugPrint('[TDLib] SetTdlibParameters error: $e');
      }
    } else if (state is td.AuthorizationStateWaitPhoneNumber) {
      _updateStatus('Ready for authentication.');
    } else if (state is td.AuthorizationStateReady) {
      _updateStatus('Authenticated with Telegram!');
    }
  }

  /// Completely wipe local TDLib database and reset connection.
  Future<void> resetSession() async {
    try {
      _updateStatus('Resetting TDLib local data...');
      _pollTimer?.cancel();
      _pollTimer = null;
      _clientId = null;
      _initializeMemoizer = null;
      _currentAuthState = null;

      final appDir = await getApplicationDocumentsDirectory();
      final databaseDir = Directory('${appDir.path}/tdlib');
      if (await databaseDir.exists()) {
        await databaseDir.delete(recursive: true);
      }
      _updateStatus('Local session reset. Re-initializing...');
      await initialize();
    } catch (e) {
      _updateStatus('Error resetting session: $e');
    }
  }

  /// Close TDLib client and release resources.
  Future<void> dispose() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await _updatesController.close();
    await _invokesController.close();
    await _authEventController.close();
    await _statusMessageController.close();
    await _fileUpdateController.close();
    _clientId = null;
  }
}

/// Riverpod provider for TdlibService.
final tdlibServiceProvider = Provider<TdlibService>((ref) {
  final service = TdlibService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
