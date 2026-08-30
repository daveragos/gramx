import 'package:gramx/features/feed/domain/post.dart';

/// How a post's reply target gets drawn.
///
/// it drew Telegram's tinted block with an accent bar down the left edge, in
/// only on whether there is anything of the quoted post to show, so the choice
/// lives here rather than being re-derived by each widget that draws it.
enum ReplyPresentation {
  /// The post answers nothing. Draw neither shape.
  none,

  /// whose parent the reader can already see, or whose content Telegram never
  /// sent. Nothing is drawn around it.
  line,

  /// byline, its words and its picture. Earned by having something to put in
  /// it — an empty bordered box is worse than the line.
  card,
}

/// Whether [post] answers another message at all.
///
/// Any one of the three is enough: TDLib fills them independently, and a reply
/// whose excerpt never resolved still has a message id worth linking to.
bool hasReplyTarget(Post post) =>
    post.replyToMessageId != null ||
    post.replyToAuthorTitle != null ||
    post.replyToText != null;

/// Whether there is enough of the quoted post to fill a card.
bool hasQuotedContent(Post post) {
  final text = post.replyToText;
  if (text != null && text.trim().isNotEmpty) return true;
  if (post.replyToThumbnailFileId != null &&
      post.replyToThumbnailFileId != 0) {
    return true;
  }
  final url = post.replyToThumbnailUrl;
  return url != null && url.isNotEmpty;
}

/// Which shape [post]'s reply target gets.
ReplyPresentation replyPresentationFor(Post post) {
  if (!hasReplyTarget(post)) return ReplyPresentation.none;
  return hasQuotedContent(post)
      ? ReplyPresentation.card
      : ReplyPresentation.line;
}
