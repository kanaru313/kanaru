import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show LicenseRegistry;
import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/app_font.dart';
import 'package:kanaru/core/settings/app_font_licenses.dart';

class _FakeBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode('license of $key')));
}

void main() {
  testWidgets('Inter and Nunito get their own license text', (tester) async {
    registerFontLicenses(bundle: _FakeBundle());
    final byPackage = <String, String>{};
    await for (final entry in LicenseRegistry.licenses) {
      if (entry.packages.length != 1) continue;
      final name = entry.packages.single;
      if (name != 'Inter' && name != 'Nunito') continue;
      byPackage[name] = entry.paragraphs.map((p) => p.text).join(' ');
    }
    expect(byPackage['Inter'], contains(appFontFor('inter').licenseAsset!));
    expect(byPackage['Nunito'], contains(appFontFor('nunito').licenseAsset!));
  });
}
