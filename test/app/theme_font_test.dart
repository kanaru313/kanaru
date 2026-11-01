import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final family in ['Inter', 'Nunito', 'sans-serif']) {
      test('text styles use $family (${brightness.name})', () {
        final theme = buildTheme(null, brightness, fontFamily: family);
        expect(theme.textTheme.bodyMedium!.fontFamily, family);
        expect(theme.textTheme.titleLarge!.fontFamily, family);
        expect(theme.snackBarTheme.contentTextStyle!.fontFamily, family);
      });
    }
  }

  test('a cover seed keeps the font', () {
    final theme = buildTheme(
      null,
      Brightness.dark,
      coverSeed: const Color(0xFFC62828),
      fontFamily: 'Nunito',
    );
    expect(theme.textTheme.bodyMedium!.fontFamily, 'Nunito');
  });

  test('the theme is cached per font', () {
    final a = buildTheme(null, Brightness.light, fontFamily: 'Nunito');
    expect(
      identical(a, buildTheme(null, Brightness.light, fontFamily: 'Nunito')),
      isTrue,
    );
    expect(
      identical(a, buildTheme(null, Brightness.light, fontFamily: 'Inter')),
      isFalse,
    );
  });
}
