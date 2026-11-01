import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final brightness in Brightness.values) {
    test('text styles use the bundled Inter font (${brightness.name})', () {
      final theme = buildTheme(null, brightness);
      expect(theme.textTheme.bodyMedium!.fontFamily, 'Inter');
      expect(theme.textTheme.titleLarge!.fontFamily, 'Inter');
      expect(theme.snackBarTheme.contentTextStyle!.fontFamily, 'Inter');
    });
  }

  test('a cover seed keeps the font', () {
    final theme = buildTheme(
      null,
      Brightness.dark,
      coverSeed: const Color(0xFFC62828),
    );
    expect(theme.textTheme.bodyMedium!.fontFamily, 'Inter');
  });
}
