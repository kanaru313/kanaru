import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/app_font.dart';

void main() {
  test('resolves built-in fonts', () {
    expect(appFontFor('inter').family, 'Inter');
    expect(appFontFor('nunito').family, 'Nunito');
  });

  test('resolves every catalog font', () {
    expect(appFontFor('be-vietnam-pro').family, 'Be Vietnam Pro');
    expect(appFontFor('plus-jakarta-sans').family, 'Plus Jakarta Sans');
    expect(appFontFor('roboto').family, 'Roboto');
    expect(appFontFor('lexend').family, 'Lexend');
    expect(appFontFor('lora').family, 'Lora');
    expect(appFontFor('fira-sans').family, 'Fira Sans');
    expect(appFontFor('jetbrains-mono').family, 'JetBrains Mono');
  });

  test('resolves custom fonts and strips the hash from the fallback label', () {
    final font = appFontFor('custom_my_font_1a2b3c4d');
    expect(font.family, 'custom_my_font_1a2b3c4d');
    expect(font.label, 'my font');
    expect(isCustomFontId('custom_x_00000000'), isTrue);
    expect(isCustomFontId('inter'), isFalse);
  });

  test('unknown ids fall back to the default font', () {
    expect(appFontFor('unknown').id, defaultFontId);
  });
}
