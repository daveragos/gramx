import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/trok/data/http_trok_client.dart';
import 'package:gramx/features/trok/data/trok_credentials.dart';
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

final trokClientProvider = Provider<TrokClient>((ref) {
  final client = HttpTrokClient(
    credentials: TdlibTrokCredentials(ref.watch(tdlibServiceProvider)),
  );
  ref.onDispose(client.close);
  return client;
});
