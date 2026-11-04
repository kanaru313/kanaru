import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/app_font.dart';

void main() {
  test('ids are unique', () {
    final ids = builtInAppFonts.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('exactly one entry is the default', () {
    expect(builtInAppFonts.where((f) => f.id == defaultFontId), hasLength(1));
    expect(appFontFor(defaultFontId).family, 'Nunito');
    expect(defaultFontId, 'nunito');
  });

  test('an unknown id gives the default font', () {
    expect(appFontFor('nope').id, defaultFontId);
    expect(appFontFor('').id, defaultFontId);
  });

  test('system is the generic sans-serif family', () {
    expect(appFontFor(systemFontId).family, 'sans-serif');
  });

  test('nunito resolves', () {
    expect(appFontFor('nunito').family, 'Nunito');
  });

  test('every bundled font with a family has a license', () {
    for (final f in builtInAppFonts.where(
      (f) => f.bundled && f.id != systemFontId,
    )) {
      expect(f.licenseAsset, isNotNull, reason: f.id);
    }
  });

  test('isCustomFontId identifies custom font prefix', () {
    expect(isCustomFontId('custom_my_font_1a2b3c4d'), isTrue);
    expect(isCustomFontId('custom_test'), isTrue);
    expect(isCustomFontId('nunito'), isFalse);
    expect(isCustomFontId('be-vietnam-pro'), isFalse);
  });

  test('customFontFallbackLabel formats id into readable label', () {
    expect(
      customFontFallbackLabel('custom_my_font_1a2b3c4d'),
      'my font',
    );
    expect(customFontFallbackLabel('custom_roboto_slab'), 'roboto slab');
  });

  test('appFontFor resolves catalog font', () {
    final font = appFontFor('be-vietnam-pro');
    expect(font.id, 'be-vietnam-pro');
    expect(font.label, 'Be Vietnam Pro');
    expect(font.family, 'Be Vietnam Pro');
    expect(font.bundled, isFalse);
  });

  test('appFontFor resolves custom font', () {
    final font = appFontFor('custom_my_font_1a2b3c4d');
    expect(font.id, 'custom_my_font_1a2b3c4d');
    expect(font.label, 'my font');
    expect(font.family, 'custom_my_font_1a2b3c4d');
    expect(font.bundled, isFalse);
  });
}
