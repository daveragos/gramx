import 'dart:io';

import 'package:handy_tdlib/handy_tdlib.dart';

/// Opens TDLib's native library for [TdPlugin].
///
/// On Android it is handy_tdlib's `libtdjson.so`. handy_tdlib has no iOS
/// build, so the iOS app embeds its own as `tdjson.framework`, built by
/// `tool/build_tdlib_ios.sh`.
Future<void> openTdlib() =>
    TdPlugin.initialize(Platform.isIOS ? 'tdjson.framework/tdjson' : null);
