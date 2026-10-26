import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/theme.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/app_snack_bar.dart';
import 'package:material_ui/material_ui.dart';

Future<ThemeData> _pump(WidgetTester tester, Widget child) async {
  final theme = buildTheme(null, Brightness.light);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  return theme;
}

final _contentRow = find.descendant(
  of: find.byType(AppSnackBarContent),
  matching: find.byType(Row),
);

// The theme as widgets see it, with the text styles resolved for the platform.
ThemeData _resolved(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(AppSnackBarContent)));

void main() {
  group('AppSnackBarContent icon', () {
    final cases = <(AppSnackBarKind, IconData, Color Function(ColorScheme))>[
      (AppSnackBarKind.success, AppIcons.success, (c) => c.primary),
      (AppSnackBarKind.info, AppIcons.info, (c) => c.onSurfaceVariant),
      (AppSnackBarKind.warning, AppIcons.warningRounded, (c) => c.tertiary),
      (AppSnackBarKind.error, AppIcons.errorRounded, (c) => c.error),
    ];
    for (final (kind, data, color) in cases) {
      testWidgets('${kind.name} uses its icon and color', (tester) async {
        final theme = await _pump(
          tester,
          AppSnackBarContent(kind: kind, title: 'Title'),
        );
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.icon, data);
        expect(icon.color, color(theme.colorScheme));
        expect(icon.size, 24);
      });
    }
  });

  group('AppSnackBarContent layout', () {
    testWidgets('title only: one bold text, icon centered', (tester) async {
      final theme = await _pump(
        tester,
        const AppSnackBarContent(kind: AppSnackBarKind.success, title: 'Added'),
      );
      expect(find.byType(Text), findsOneWidget);
      final style = tester.widget<Text>(find.text('Added')).style!;
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, theme.colorScheme.onSurface);
      expect(style.fontSize, _resolved(tester).textTheme.titleSmall?.fontSize);
      expect(
        tester.widget<Row>(_contentRow).crossAxisAlignment,
        CrossAxisAlignment.center,
      );
    });

    testWidgets('with details: two texts, icon at the top', (tester) async {
      final theme = await _pump(
        tester,
        const AppSnackBarContent(
          kind: AppSnackBarKind.warning,
          title: 'Done',
          details: '3 new',
        ),
      );
      expect(find.byType(Text), findsNWidgets(2));
      final details = tester.widget<Text>(find.text('3 new')).style!;
      expect(details.color, theme.colorScheme.onSurfaceVariant);
      expect(
        details.fontSize,
        _resolved(tester).textTheme.bodyMedium?.fontSize,
      );
      expect(
        tester.widget<Row>(_contentRow).crossAxisAlignment,
        CrossAxisAlignment.start,
      );
    });
  });

  group('appSnackBar', () {
    test('passes action, duration and onVisible through', () {
      var visible = false;
      final action = SnackBarAction(label: 'Undo', onPressed: () {});
      final bar = appSnackBar(
        kind: AppSnackBarKind.info,
        title: 'T',
        action: action,
        duration: const Duration(seconds: 8),
        onVisible: () => visible = true,
      );
      expect(bar.action, same(action));
      expect(bar.duration, const Duration(seconds: 8));
      bar.onVisible!();
      expect(visible, isTrue);
      final content = bar.content as AppSnackBarContent;
      expect(content.kind, AppSnackBarKind.info);
      expect(content.details, isNull);
    });

    test('persist stays null with an action, so the SnackBar persists', () {
      final bar = appSnackBar(
        kind: AppSnackBarKind.warning,
        title: 'T',
        action: SnackBarAction(label: 'Open', onPressed: () {}),
      );
      expect(bar.persist, isTrue);
    });

    test('persist false is kept', () {
      final bar = appSnackBar(
        kind: AppSnackBarKind.success,
        title: 'T',
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
        persist: false,
      );
      expect(bar.persist, isFalse);
    });

    test('default duration is the SnackBar default', () {
      final bar = appSnackBar(kind: AppSnackBarKind.error, title: 'T');
      expect(bar.duration, const Duration(milliseconds: 4000));
    });
  });
}
