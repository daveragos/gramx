import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds gramX's own notice and license to the licenses page, ahead of the
/// packages it uses. A work based on gramX keeps this screen, and with it the
/// credit the license asks it to keep.
void registerAppLicense() {
  LicenseRegistry.addLicense(() async* {
    final notice = await rootBundle.loadString('NOTICE');
    final license = await rootBundle.loadString('LICENSE');
    yield LicenseEntryWithLineBreaks(const ['gramX'], '$notice\n\n$license');
  });
}
