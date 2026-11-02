import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Include Frog File Viewer's generated notices in Flutter's license browser.
///
/// Listing the text file as a Flutter asset alone does not register its contents
/// with showLicensePage(). This registry entry makes the bundled notices
/// discoverable from the app's "Open-source licenses" button.
bool _noticesRegistered = false;

void registerBundledThirdPartyLicenses() {
  if (_noticesRegistered) return;
  _noticesRegistered = true;
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/THIRD_PARTY_NOTICES.txt');
    yield LicenseEntryWithLineBreaks(
      const ['Frog File Viewer — bundled third-party notices'],
      text,
    );
  });
}
