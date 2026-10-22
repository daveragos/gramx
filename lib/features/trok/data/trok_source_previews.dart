import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// What Telegram shows for a link: the site, the page's title and
/// description, and its picture.
class TrokLinkPreview {
  final String siteName;
  final String title;
  final String description;

  /// TDLib's id for the picture, if the page has one.
  final int? imageFileId;

  const TrokLinkPreview({
    required this.siteName,
    required this.title,
    required this.description,
    this.imageFileId,
  });
}

/// The post a t.me [link] opens, as `chatId_messageId`, for a post Trok
/// found that gramX doesn't hold. Null when Telegram won't show it. Kept
/// for the session, so cards scrolled past aren't looked up again.
final trokLinkedPostIdProvider = FutureProvider.family<String?, String>((
  ref,
  link,
) async {
  try {
    final info = await ref
        .watch(tdlibServiceProvider)
        .sendRequest(td.GetMessageLinkInfo(url: link));
    if (info is! td.MessageLinkInfo) return null;
    final message = info.message;
    return message == null ? null : '${info.chatId}_${message.id}';
  } on Object catch (e) {
    debugPrint('[Trok] no post at $link: $e');
    return null;
  }
});

/// Telegram's preview of [url]. Telegram fetches the page, not the phone,
/// so the site doesn't see who is reading. Null when Telegram has none.
/// Kept for the session: Telegram asks that it not be called too often.
final trokLinkPreviewProvider = FutureProvider.family<TrokLinkPreview?, String>(
  (ref, url) async {
    try {
      final preview = await ref
          .watch(tdlibServiceProvider)
          .sendRequest(
            td.GetLinkPreview(
              text: td.FormattedText(
                text: url,
                entities: [
                  td.TextEntity(
                    offset: 0,
                    length: url.length,
                    type: const td.TextEntityTypeUrl(),
                  ),
                ],
              ),
            ),
          );
      if (preview is! td.LinkPreview) return null;
      return TrokLinkPreview(
        siteName: preview.siteName,
        title: preview.title,
        description: preview.description.text,
        imageFileId: TdlibMappers.linkPreviewImage(preview.type)?.id,
      );
    } on Object catch (e) {
      debugPrint('[Trok] no preview of $url: $e');
      return null;
    }
  },
);
