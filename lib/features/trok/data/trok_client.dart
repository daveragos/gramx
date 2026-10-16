import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/trok/data/preview_trok_client.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';

/// Answers questions for Trok. Argus, a Telegram bot, is meant to answer
/// behind this; until it does, [PreviewTrokClient] answers from the feed.
abstract interface class TrokClient {
  /// Answers [request]. Cancelling the subscription stops the answer.
  Stream<TrokEvent> ask(TrokRequest request);
}

final trokClientProvider = Provider<TrokClient>(
  (ref) => const PreviewTrokClient(),
);
