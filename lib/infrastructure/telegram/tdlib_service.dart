import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:handy_tdlib/handy_tdlib.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gramx/core/config/app_config.dart';
import 'package:gramx/infrastructure/telegram/database_key_store.dart';
import 'package:gramx/infrastructure/telegram/file_update_throttle.dart';
import 'package:gramx/infrastructure/telegram/tdlib_receiver.dart';

/// A failed TDLib request, carrying the numeric error code.
///
/// The code is what makes rate limiting detectable — collapsing a [td.TdError]
/// into a bare `Exception` throws it away and leaves 420/429 indistinguishable
/// from a bad request.
///
/// [toString] deliberately returns only [message]: the auth screens surface it
/// to the user verbatim, so a type prefix would leak internals into sign-in.
class TdlibRequestException implements Exception {
  /// TDLib error code — 400 bad request, 401 unauthorised, 420/429 flood wait.
  final int code;

  /// Raw Telegram error string, e.g. `PHONE_NUMBER_INVALID`.
  final String message;

  const TdlibRequestException(this.code, this.message);

  /// True when Telegram is rate-limiting the account.
  bool get isFloodWait =>
      code == TdlibService.floodWaitCode ||
      code == TdlibService.tooManyRequestsCode;

  /// Seconds Telegram asked us to wait, or null if the message didn't say.
  int? get retryAfterSeconds => TdlibService.parseRetryAfter(message);

  @override
  String toString() => message;
}

/// Service wrapper around native TDLib (handy_tdlib).
class TdlibService {
  /// TDLib's own flood-wait code.
  static const int floodWaitCode = 420;

  /// HTTP-style rate-limit code TDLib also emits. Both must be recognised.
  static const int tooManyRequestsCode = 429;

  /// Longest flood wait we will sit through inside [sendRequest]. Past this the
  /// request is rejected locally so callers fail fast instead of hanging.
  static const Duration maxInlineFloodWait = Duration(seconds: 45);

  /// Used when Telegram reports a flood wait without a parseable duration.
  static const Duration _defaultFloodWait = Duration(seconds: 5);

  static final RegExp _retryAfterPattern = RegExp(
    r'(?:FLOOD_WAIT_|retry after\s*)(\d+)',
    caseSensitive: false,
  );

  /// Extracts the retry delay from a TDLib error message.
  ///
  /// Handles both `FLOOD_WAIT_30` and `Too Many Requests: retry after 30`.
  static int? parseRetryAfter(String message) {
    final match = _retryAfterPattern.firstMatch(message);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  int? _clientId;
  Future<void>? _initializeMemoizer;
  Timer? _pollTimer;

  /// Non-null while updates are arriving on a background isolate. When null,
  /// the polling fallback owns receiving instead.
  TdlibReceiver? _receiver;

  final _updatesController = StreamController<td.TdObject>.broadcast();
  final _invokesController = StreamController<Map<String, dynamic>>.broadcast();
  final _authEventController =
      StreamController<td.AuthorizationState>.broadcast();
  final _statusMessageController = StreamController<String>.broadcast();
  final _fileUpdateController = StreamController<td.UpdateFile>.broadcast();

  td.AuthorizationState? _currentAuthState;
  String _lastStatusMessage = 'Initializing TDLib...';
  final Completer<void> _tdlibReadyCompleter = Completer<void>();

  /// Single client-wide flood-wait deadline. One gate for every request — a
  /// per-call-site retry races on release and immediately re-floods.
  DateTime? _floodWaitUntil;
  final _floodWaitController = StreamController<DateTime?>.broadcast();

  /// When Telegram is rate-limiting this account, the moment the limit lifts.
  /// Null when clear. Reading it also clears an expired deadline.
  DateTime? get floodWaitUntil {
    final until = _floodWaitUntil;
    if (until == null) return null;
    if (!until.isAfter(DateTime.now())) {
      _clearFloodWait();
      return null;
    }
    return until;
  }

  /// Emits the new deadline whenever rate limiting starts, and null when it lifts.
  Stream<DateTime?> get floodWaitUpdates => _floodWaitController.stream;

  /// Records a flood-wait deadline if [code] is a rate-limit code.
  ///
  /// Called for both request replies and global updates — TDLib's own
  /// background requests can trip the limit without any call of ours failing.
  void _noteError(int code, String message) {
    if (code != floodWaitCode && code != tooManyRequestsCode) return;

    final seconds = parseRetryAfter(message);
    final wait = seconds != null
        ? Duration(seconds: seconds)
        : _defaultFloodWait;
    final until = DateTime.now().add(wait);

    // Only ever extend the deadline, never shorten it.
    final current = _floodWaitUntil;
    if (current != null && !until.isAfter(current)) return;

    _floodWaitUntil = until;
    _floodWaitController.add(until);
    debugPrint(
      '[TDLib] Rate limited (code $code): $message — gating requests for ${wait.inSeconds}s',
    );
  }

  void _clearFloodWait() {
    if (_floodWaitUntil == null) return;
    _floodWaitUntil = null;
    if (!_floodWaitController.isClosed) _floodWaitController.add(null);
    debugPrint('[TDLib] Rate limit lifted — resuming requests');
  }

  /// True for requests TDLib answers from its own database without reaching the
  /// server.
  ///
  /// These bypass the flood gate: a rate limit must not stop the app from
  /// reading content it already has on disk, or a flood wait would black out
  /// the cached feed instead of just pausing new fetches.
  static bool _isLocalOnlyRequest(td.TdFunction function) {
    if (function is td.GetChatHistory) return function.onlyLocal;
    // Options live in TDLib's own store, pushed there by `updateOption` — a
    // read never leaves the device. TDLib documents `getOption` as callable
    // before authorization, which is only possible because it is local.
    if (function is td.GetOption) return true;
    // TDLib documents `searchChats` as an offline method: it searches the
    // titles and usernames of chats it has *already* loaded and never asks the
    // server. That is what makes the new-message picker free to type in — see
    // the per-keystroke rule in docs/TDLIB.md.
    if (function is td.SearchChats) return true;
    // TDLib's own documentation on `getMessageProperties`: "this is an offline
    // request". It is what the message long-press menu asks before deciding
    // which actions to offer, so it must not be gated behind a flood wait the
    // reader would experience as a menu that never opens.
    if (function is td.GetMessageProperties) return true;
    return function is td.GetMessageLocally;
  }

  /// Parks until the flood-wait deadline lifts.
  ///
  /// Loops rather than sleeping once, so a fresh flood recorded while we are
  /// parked extends the wait instead of releasing a burst of requests early.
  Future<void> _awaitFloodGate(td.TdFunction function) async {
    while (true) {
      final until = _floodWaitUntil;
      if (until == null) return;

      final remaining = until.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _clearFloodWait();
        return;
      }

      if (remaining > maxInlineFloodWait) {
        throw TdlibRequestException(
          floodWaitCode,
          'FLOOD_WAIT_${remaining.inSeconds}',
        );
      }

      // Small grace so the deadline is genuinely past when we re-check.
      await Future<void>.delayed(remaining + const Duration(milliseconds: 50));
    }
  }

  void _markTdlibReady() {
    if (!_tdlibReadyCompleter.isCompleted) {
      _tdlibReadyCompleter.complete();
    }
  }

  void _markTdlibError(Object error) {
    if (!_tdlibReadyCompleter.isCompleted) {
      _tdlibReadyCompleter.completeError(error);
    }
  }

  final DatabaseKeyStore _keyStore;

  TdlibService(Ref ref, {DatabaseKeyStore? keyStore})
    : _keyStore = keyStore ?? DatabaseKeyStore();

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

      // Start receiving (isolate if possible, polling otherwise)
      await _startReceiving();

      // Query current authorization state immediately to seed the service
      try {
        _updateStatus('Connecting to Telegram network...');
        final stateRes = await sendRequest(const td.GetAuthorizationState());
        if (stateRes is td.AuthorizationState) {
          _handleIncomingUpdate(
            td.UpdateAuthorizationState(authorizationState: stateRes),
          );
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

  /// Fastest poll, used while updates are actually arriving.
  static const Duration _activePollInterval = Duration(milliseconds: 50);

  /// Slowest poll, used once the queue has been empty for a while. A fixed
  /// 50 ms timer woke the app twenty times a second even on an idle screen.
  static const Duration _idlePollInterval = Duration(milliseconds: 250);

  /// Empty drains before backing off.
  static const int _idleThreshold = 8;

  /// Updates decoded per drain before yielding to the event loop, so a burst —
  /// a media download emits `UpdateFile` continuously — can't monopolise a frame.
  static const int _maxDrainBatch = 64;

  int _emptyDrains = 0;
  Duration _pollInterval = _activePollInterval;

  /// Starts receiving updates.
  ///
  /// Prefers a background isolate running TDLib's blocking receive, which keeps
  /// both the native wait and the JSON parse off the UI thread. Falls back to
  /// polling here if the isolate can't be started — on a platform that links
  /// TDLib statically, for instance — so a failure degrades to the previous
  /// behaviour rather than a client that receives nothing.
  ///
  /// Exactly one of the two runs: `td_receive` must not be called concurrently
  /// for the same client.
  Future<void> _startReceiving() async {
    _receiver = TdlibReceiver(onPayload: _handlePayload);
    if (await _receiver!.start()) return;

    _receiver = null;
    _startPolling();
  }

  /// Non-blocking polling loop, backing off while nothing is arriving.
  void _startPolling() {
    _scheduleNextPoll(_activePollInterval);
  }

  void _scheduleNextPoll(Duration interval) {
    _pollTimer?.cancel();
    _pollInterval = interval;
    _pollTimer = Timer.periodic(interval, (_) => _drainUpdates());
  }

  /// Speeds the loop up on activity and slows it down when idle.
  void _adjustPollRate({required bool drainedAnything}) {
    if (drainedAnything) {
      _emptyDrains = 0;
      if (_pollInterval != _activePollInterval) {
        _scheduleNextPoll(_activePollInterval);
      }
      return;
    }

    if (_pollInterval == _idlePollInterval) return;
    if (++_emptyDrains >= _idleThreshold) {
      _scheduleNextPoll(_idlePollInterval);
    }
  }

  final Map<String, Completer<td.TdObject>> _pendingRequests = {};

  /// Drains pending updates from the native queue.
  ///
  /// Decodes each payload exactly once. The previous version parsed every
  /// update twice — once for the `@extra` check and again inside
  /// `convertJsonToObject` — and request replies were additionally re-encoded
  /// back to a string in between, so a reply cost two parses and one encode.
  void _drainUpdates() {
    var drained = 0;

    while (drained < _maxDrainBatch) {
      final String? response = TdPlugin.instance.tdReceive(0);
      if (response == null || response.isEmpty) break;
      drained++;

      try {
        _handlePayload(jsonDecode(response) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[TDLib] JSON decode error on update: $e');
      }
    }

    _adjustPollRate(drainedAnything: drained > 0);
  }

  /// Whether a payload is a reply to a request we sent.
  ///
  /// Presence of the key — not a non-null value — is what marks a reply,
  /// matching how TDLib echoes `@extra` back. Checking for a non-null value
  /// instead would misroute a reply carrying a null one into the update stream.
  @visibleForTesting
  static bool isRequestReply(Map<String, dynamic> payload) =>
      payload.containsKey('@extra');

  /// Routes one decoded TDLib payload, from either receive path.
  void _handlePayload(Map<String, dynamic> map) {
    if (isRequestReply(map)) {
      final extra = map['@extra']?.toString();
      final completer = extra != null ? _pendingRequests.remove(extra) : null;
      if (completer != null) {
        _completeRequest(completer, map);
      } else {
        _invokesController.add(map);
      }
      return;
    }

    final object = convertMapToObject(map);
    if (object != null) _handleIncomingUpdate(object);
  }

  void _completeRequest(
    Completer<td.TdObject> completer,
    Map<String, dynamic> map,
  ) {
    final object = convertMapToObject(map);
    if (object == null) {
      completer.completeError(
        Exception('Failed to deserialize TDLib response.'),
      );
      return;
    }
    if (object is td.TdError) {
      _noteError(object.code, object.message);
      completer.completeError(
        TdlibRequestException(object.code, object.message),
      );
      return;
    }
    completer.complete(object);
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

    // Gate non-init requests until TDLib parameters are configured, then behind
    // the flood-wait deadline. Bootstrap calls bypass both — without them the
    // client can never recover from a rate limit.
    if (function is! td.SetTdlibParameters &&
        function is! td.GetAuthorizationState) {
      try {
        await _tdlibReadyCompleter.future.timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[TDLib] Gate wait note: $e');
      }
      if (!_isLocalOnlyRequest(function)) {
        await _awaitFloodGate(function);
      }
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
        throw TimeoutException(
          'TDLib request ${function.runtimeType} timed out.',
        );
      },
    );
  }

  List<td.ChatFolderInfo> _chatFolders = [];
  List<td.ChatFolderInfo> get chatFolders => _chatFolders;

  void _handleIncomingUpdate(td.TdObject object) {
    if (object is td.UpdateAuthorizationState) {
      _currentAuthState = object.authorizationState;
      debugPrint(
        '[TDLib Update] UpdateAuthorizationState -> ${object.authorizationState.runtimeType}',
      );
      _authEventController.add(object.authorizationState);
      _handleAuthorizationState(object.authorizationState);
    } else if (object is td.UpdateChatFolders) {
      _chatFolders = object.chatFolders;
    } else if (object is td.TdError) {
      // TDLib's own background requests can trip the rate limit without any
      // request of ours failing, so global errors feed the gate too.
      _noteError(object.code, object.message);
      debugPrint('[TDLib Global Error] ${object.code}: ${object.message}');
    }
    if (object is td.UpdateFile) _emitFileUpdate(object);
    _updatesController.add(object);
  }

  /// Keeps download progress affordable to draw. See [FileUpdateThrottle] —
  /// the rule lives there so it can be tested without a client.
  final FileUpdateThrottle _fileThrottle = FileUpdateThrottle();

  /// Forwards a file update to the UI stream, rate-limited per file.
  void _emitFileUpdate(td.UpdateFile update) {
    final allowed = _fileThrottle.allow(
      fileId: update.file.id,
      isCompleted: update.file.local.isDownloadingCompleted,
      now: DateTime.now(),
    );
    if (allowed) _fileUpdateController.add(update);
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

        // A null stored key means either a fresh install or a database created
        // before encryption existed. Both are opened with an empty key and then
        // encrypted in place below, so an upgrade doesn't orphan the cache.
        final storedKey = await _keyStore.read();

        final request = td.SetTdlibParameters(
          useTestDc: false,
          databaseDirectory: databaseDir,
          filesDirectory: filesDir,
          databaseEncryptionKey: storedKey ?? '',
          useFileDatabase: true,
          useChatInfoDatabase: true,
          useMessageDatabase: true,
          useSecretChats: false,
          apiId: AppConfig.apiId,
          apiHash: AppConfig.apiHash,
          systemLanguageCode: 'en',
          deviceModel: 'gramX',
          systemVersion: 'Android/iOS',
          // What Telegram shows for this session under Settings → Devices,
          // so it has to be the version actually installed.
          applicationVersion: AppStrings.appVersion,
        );

        final res = await sendRequest(request);
        if (res is td.TdError) {
          _updateStatus('Parameter error: ${res.message}');
          _markTdlibError(Exception(res.message));
        } else {
          _updateStatus('Parameters accepted by Telegram.');
          _markTdlibReady();
          if (storedKey == null) await _encryptDatabase();
          try {
            await sendRequest(
              const td.SetLogVerbosityLevel(newVerbosityLevel: 1),
            );
          } catch (_) {}
        }
      } catch (e) {
        _updateStatus('Failed to set TDLib parameters: $e');
        _markTdlibError(e);
        debugPrint('[TDLib] SetTdlibParameters error: $e');
      }
    } else if (state is td.AuthorizationStateWaitPhoneNumber ||
        state is td.AuthorizationStateWaitCode ||
        state is td.AuthorizationStateWaitPassword ||
        state is td.AuthorizationStateWaitOtherDeviceConfirmation ||
        state is td.AuthorizationStateReady) {
      _markTdlibReady();
      if (state is td.AuthorizationStateWaitPhoneNumber) {
        _updateStatus('Ready for authentication.');
      } else if (state is td.AuthorizationStateReady) {
        _updateStatus('Authenticated with Telegram!');
        try {
          sendRequest(
            const td.LoadChats(chatList: td.ChatListMain(), limit: 100),
          );
        } catch (_) {}
      }
    }
  }

  /// Encrypts the local database and stores the key in the platform keystore.
  ///
  /// Runs once, right after an unencrypted open. The key is persisted only
  /// after TDLib confirms the change — storing it first would leave a key that
  /// doesn't open the database, which is unrecoverable without a wipe.
  Future<void> _encryptDatabase() async {
    final key = DatabaseKeyStore.generate();
    try {
      await sendRequest(td.SetDatabaseEncryptionKey(newEncryptionKey: key));
      await _keyStore.write(key);
      debugPrint('[TDLib] Local database encrypted');
    } catch (e) {
      // The database stays readable with an empty key; we simply try again on
      // the next launch rather than leaving a mismatched key behind.
      debugPrint('[TDLib] Could not encrypt local database: $e');
    }
  }

  /// Brings the client back after TDLib closed it, keeping the local data.
  ///
  /// TDLib closes the client after a log out and answers nothing further until
  /// a new one exists. On the next launch that read as a broken app —
  /// "Telegram session closed", offering to wipe local data — when all that is
  /// needed is a fresh client on the same database. It comes back at
  /// `WaitPhoneNumber`, which is the sign-in screen.
  Future<void> restartClient() async {
    _updateStatus('Reconnecting to Telegram...');
    _pollTimer?.cancel();
    _pollTimer = null;
    await _receiver?.stop();
    _receiver = null;
    _clientId = null;
    _initializeMemoizer = null;
    _currentAuthState = null;
    await initialize();
  }

  /// Completely wipe local TDLib database and reset connection.
  Future<void> resetSession() async {
    try {
      _updateStatus('Resetting TDLib local data...');
      _pollTimer?.cancel();
      _pollTimer = null;
      await _receiver?.stop();
      _receiver = null;
      _clientId = null;
      _initializeMemoizer = null;
      _currentAuthState = null;

      final appDir = await getApplicationDocumentsDirectory();
      final databaseDir = Directory('${appDir.path}/tdlib');
      if (await databaseDir.exists()) {
        await databaseDir.delete(recursive: true);
      }
      // The key belongs to the database we just deleted. Keeping it would make
      // the next launch open a fresh database with a stale key and fail.
      await _keyStore.clear();
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
    await _receiver?.stop();
    _receiver = null;
    await _updatesController.close();
    await _invokesController.close();
    await _authEventController.close();
    await _statusMessageController.close();
    await _fileUpdateController.close();
    await _floodWaitController.close();
    _clientId = null;
  }
}

/// Riverpod provider for TdlibService.
final tdlibServiceProvider = Provider<TdlibService>((ref) {
  final service = TdlibService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
