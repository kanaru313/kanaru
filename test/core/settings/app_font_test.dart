import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/app_font.dart';

void main() {
  test('ids are unique', () {
    final ids = builtInAppFonts.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('exactly one entry is the default', () {
    expect(builtInAppFonts.where((f) => f.id == defaultFontId), hasLength(1));
    expect(appFontFor(defaultFontId).family, 'Inter');
  });

  test('an unknown id gives Inter', () {
    expect(appFontFor('nope').id, defaultFontId);
    expect(appFontFor('').id, defaultFontId);
  });

  test('system has no family', () {
    expect(appFontFor(systemFontId).family, isNull);
  });

  test('nunito resolves', () {
    expect(appFontFor('nunito').family, 'Nunito');
  });

  test('every bundled font with a family has a license', () {
    for (final f in builtInAppFonts.where(
      (f) => f.bundled && f.family != null,
    )) {
      expect(f.licenseAsset, isNotNull, reason: f.id);
    }
  });
}
