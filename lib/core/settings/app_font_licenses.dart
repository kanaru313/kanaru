import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'app_font.dart';

/// Adds one licenses-page entry per bundled font that has a license text.
/// Read lazily (when the page opens), so no startup cost. [bundle] is for
/// tests.
void registerFontLicenses({AssetBundle? bundle}) {
  LicenseRegistry.addLicense(() async* {
    final source = bundle ?? rootBundle;
    for (final font in builtInAppFonts) {
      final asset = font.licenseAsset;
      if (!font.bundled || asset == null) continue;
      yield LicenseEntryWithLineBreaks([
        font.label,
      ], await source.loadString(asset));
    }
  });
}
