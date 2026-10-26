import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('snackBarTheme', () {
    final themes = {
      'light': buildTheme(null, Brightness.light),
      'dark': buildTheme(null, Brightness.dark),
      'cover seed': buildTheme(
        null,
        Brightness.light,
        coverSeed: const Color(0xFFC62828),
      ),
    };

    for (final MapEntry(:key, :value) in themes.entries) {
      test('is a floating card on a surface container ($key)', () {
        final colors = value.colorScheme;
        final snack = value.snackBarTheme;
        expect(snack.behavior, SnackBarBehavior.floating);
        expect(snack.width, 440);
        expect(snack.backgroundColor, colors.surfaceContainerHigh);
        expect(snack.elevation, 3);
        expect(
          snack.shape,
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        );
        expect(snack.contentTextStyle?.color, colors.onSurface);
        expect(
          snack.contentTextStyle?.fontSize,
          value.textTheme.bodyMedium?.fontSize,
        );
        expect(snack.actionTextColor, colors.primary);
        expect(snack.closeIconColor, colors.onSurfaceVariant);
        expect(snack.showCloseIcon, isTrue);
      });
    }
  });

  group('plain SnackBar under the app theme', () {
    final theme = buildTheme(null, Brightness.light);

    Future<void> show(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(bottomNavigationBar: SizedBox(height: 80)),
        ),
      );
      final context = tester.element(find.byType(Scaffold));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('x'),
          action: SnackBarAction(label: 'Undo', onPressed: () {}),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
    }

    testWidgets('is 440 px wide, centered, on surfaceContainerHigh', (
      tester,
    ) async {
      await show(tester, const Size(800, 600));
      final card = find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first;
      final rect = tester.getRect(card);
      expect(rect.width, 440);
      expect(rect.center.dx, 400);
      final material = tester.widget<Material>(card);
      expect(material.color, theme.colorScheme.surfaceContainerHigh);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('stays 440 px wide in a 480 px window', (tester) async {
      await show(tester, const Size(480, 600));
      final card = find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.getRect(card).width, 440);
    });

    testWidgets('draws the action in the primary color', (tester) async {
      await show(tester, const Size(800, 600));
      final button = tester.widget<TextButton>(
        find.descendant(
          of: find.byType(SnackBarAction),
          matching: find.byType(TextButton),
        ),
      );
      final color = button.style?.foregroundColor?.resolve(<WidgetState>{});
      expect(color, theme.colorScheme.primary);
    });
  });
}
