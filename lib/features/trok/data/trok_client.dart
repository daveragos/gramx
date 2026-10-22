import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/settings/data/settings_store.dart';

import 'package:gramx/features/trok/data/http_trok_client.dart';
import 'package:gramx/features/trok/data/trok_credentials.dart';
import 'package:gramx/features/trok/data/trok_pictures.dart';
import 'package:gramx/features/trok/data/trok_post_files.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Answers questions for Trok, and keeps the reader's conversations with it.
abstract interface class TrokClient {
  /// Answers [request]. Cancelling the subscription stops the answer.
  Stream<TrokEvent> ask(TrokRequest request);

  /// The reader's conversations, newest first, without their messages.
  Future<List<TrokConversation>> conversations();

  /// The conversation Trok knows as [remoteId], with all its messages.
  Future<TrokConversation> conversation(String remoteId);

  Future<void> deleteConversation(String remoteId);

  /// How many questions the reader has left today, and which features are on.
  Future<TrokAllowance> allowance();
}

/// The language the reader wants Trok's answers in: `en` or `am`.
final trokAnswerLanguageProvider = Provider<String>(
  (ref) => ref
      .watch(settingsProvider.select((s) => s.trokLanguage))
      .code(PlatformDispatcher.instance.locale.languageCode),
);

final trokClientProvider = Provider<TrokClient>((ref) {
  final tdlib = ref.watch(tdlibServiceProvider);
  final client = HttpTrokClient(
    credentials: TdlibTrokCredentials(tdlib),
    // Read at each question, so a change applies without a new client.
    answerLanguage: () => ref.read(trokAnswerLanguageProvider),
    pictures: TdlibTrokPictures(tdlib),
    postFiles: TdlibTrokPostFiles(tdlib),
  );
  ref.onDispose(client.close);
  return client;
});
