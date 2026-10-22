import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/library_sort.dart';
import 'package:kanaru/features/library/widgets/library_sort_controls.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<List<SortChoice<AlbumSortField>>> pump(
    WidgetTester tester, {
    SortChoice<AlbumSortField> choice = const SortChoice(AlbumSortField.title),
    double width = 800,
  }) async {
    final changes = <SortChoice<AlbumSortField>>[];
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LibrarySortControls<AlbumSortField>(
            choice: choice,
            fields: AlbumSortField.values,
            label: albumSortLabel,
            onChanged: changes.add,
          ),
        ),
      ),
    );
    return changes;
  }

  for (final width in [800.0, 300.0]) {
    testWidgets('shows the field name and no labels at width $width', (
      tester,
    ) async {
      await pump(tester, width: width);

      expect(find.widgetWithText(TextButton, 'Title'), findsOneWidget);
      expect(find.byIcon(AppIcons.expandMore), findsOneWidget);
      expect(find.text('Sort by:'), findsNothing);
      expect(find.text('Order:'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the field button node is read out as "Sort by: Title"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    final node = tester.getSemantics(find.widgetWithText(TextButton, 'Title'));
    expect(node.label, contains('Sort by:'));
    expect(node.label, contains('Title'));
    expect(node.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('the arrow node is read out as "Order: Ascending"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    final node = tester.getSemantics(find.byTooltip('Order: Ascending'));
    expect(node.tooltip, 'Order: Ascending');
    handle.dispose();
  });

  testWidgets('the arrow shows the direction and flips it on tap', (
    tester,
  ) async {
    final changes = await pump(tester);

    expect(find.byIcon(AppIcons.sortAscending), findsOneWidget);
    expect(find.byTooltip('Order: Ascending'), findsOneWidget);
    await tester.tap(find.byTooltip('Order: Ascending'));

    expect(changes, [const SortChoice(AlbumSortField.title, descending: true)]);
  });

  testWidgets('a descending choice shows the down arrow and flips back', (
    tester,
  ) async {
    final changes = await pump(
      tester,
      choice: const SortChoice(AlbumSortField.year, descending: true),
    );

    expect(find.byIcon(AppIcons.sortDescending), findsOneWidget);
    await tester.tap(find.byTooltip('Order: Descending'));

    expect(changes, [const SortChoice(AlbumSortField.year)]);
  });

  testWidgets('picking a field keeps the direction', (tester) async {
    final changes = await pump(
      tester,
      choice: const SortChoice(AlbumSortField.title, descending: true),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Title'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Year'));
    await tester.pumpAndSettle();

    expect(changes, [const SortChoice(AlbumSortField.year, descending: true)]);
  });
}
