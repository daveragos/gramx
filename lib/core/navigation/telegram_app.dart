import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gramx/core/navigation/url_launcher_utils.dart';

/// Hands a `t.me` link to the Telegram app, for what gramX can't do itself.
///
/// On Android gramX claims `t.me` links, so a plain launch would come back
/// here; the link goes to Telegram's own packages instead. On iOS the link
/// is Telegram's universal link. Returns whether anything opened it.
Future<bool> openInTelegramApp(Uri link) async {
  if (!Platform.isAndroid) return openExternalUrl(link);
  try {
    return await _channel.invokeMethod<bool>('open', link.toString()) ??
        false;
  } catch (e) {
    debugPrint('[Telegram] hand-off failed: $e');
    return false;
  }
}

const MethodChannel _channel = MethodChannel('dev.ragoose.gramx/telegram');
