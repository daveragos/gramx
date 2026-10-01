import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds gramX's own NOTICE and LICENSE to the licenses page, ahead of the
/// packages it uses.
void registerAppLicense() {
  LicenseRegistry.addLicense(() async* {
    final notice = await rootBundle.loadString('NOTICE');
    final license = await rootBundle.loadString('LICENSE');
    yield LicenseEntryWithLineBreaks(const ['gramX'], '$notice\n\n$license');
  });
}
