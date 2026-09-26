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

  /// own byline, its words and its picture. This is a reply to the **whole**
  /// post — there is no passage to single out, so the post itself is shown.
  /// Earned by having something to put in it; an empty bordered box is worse
  /// than the line.
  card,

  /// The selected passage, standing above the reply on a thread connector.
  ///
  /// When the writer quoted a *span* rather than answering the whole post,
  /// the span is what they are talking about, so the span is what gets drawn
  /// — not the post it came out of, and not its media. It carries no action
  /// bar: a fragment of a message is not a thing that can be liked, forwarded
  /// or bookmarked, and offering the controls would be the inert affordance
  /// the hard rules forbid. The reply below keeps all of its own.
  passage,
}

/// Whether [post] answers another message at all.
///
/// Any one of the three is enough: TDLib fills them independently, and a reply
/// whose excerpt never resolved still has a message id worth linking to.
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

/// Which shape [post]'s reply target gets.
///
/// The first question is what was answered, not how much of it we have: a
/// writer who selected a passage is talking about that passage, and drawing
/// the whole post around it buries the part they picked. Only once that is
/// ruled out does having something to show decide between the card and the
/// line.
ReplyPresentation replyPresentationFor(Post post) {
  if (!hasReplyTarget(post)) return ReplyPresentation.none;
  if (post.replyToIsQuote && hasQuotedText(post)) {
    return ReplyPresentation.passage;
  }
  return hasQuotedContent(post)
      ? ReplyPresentation.card
      : ReplyPresentation.line;
}
