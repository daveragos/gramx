import 'package:gramx/features/feed/domain/post.dart';

/// How a post's reply target is drawn.
enum ReplyPresentation {
  /// The post answers nothing.
  none,

  /// One grey line naming who is being answered, used when there is nothing
  /// of the parent to show.
  line,

  /// A quote card embedding the answered post, for a reply to the whole post
  /// when there is content to show.
  card,

  /// The quoted span, drawn above the reply on a thread connector. It has no
  /// action bar, since a fragment can't be liked or forwarded.
  passage,
}

/// Whether [post] answers another message. Any of the three fields counts,
/// since TDLib fills them independently.
bool hasReplyTarget(Post post) =>
    post.replyToMessageId != null ||
    post.replyToAuthorTitle != null ||
    post.replyToText != null;

/// Whether the reply carries words from the message it answers.
bool hasQuotedText(Post post) {
  final text = post.replyToText;
  return text != null && text.trim().isNotEmpty;
}

/// Whether there is enough of the answered post to fill a card.
bool hasQuotedContent(Post post) {
  if (hasQuotedText(post)) return true;
  if (post.replyToThumbnailFileId != null && post.replyToThumbnailFileId != 0) {
    return true;
  }
  final url = post.replyToThumbnailUrl;
  return url != null && url.isNotEmpty;
}

/// Which shape [post]'s reply target gets: a quoted passage first, then a
/// card if there is content to show, else a line.
ReplyPresentation replyPresentationFor(Post post) {
  if (!hasReplyTarget(post)) return ReplyPresentation.none;
  if (post.replyToIsQuote && hasQuotedText(post)) {
    return ReplyPresentation.passage;
  }
  return hasQuotedContent(post)
      ? ReplyPresentation.card
      : ReplyPresentation.line;
}
