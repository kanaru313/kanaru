import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/shell/sidebar/sidebar_item.dart';
import 'package:kanaru/app/shell/sidebar/sidebar_toggle.dart';

import '../library/browse_test_data.dart' show location;
import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

/// The sidebar entry labelled [label]; on the rail only its tooltip says so.
Finder item(String label) =>
    find.byWidgetPredicate((w) => w is SidebarItem && w.label == label);

bool selected(WidgetTester tester, String label) =>
    tester.widget<SidebarItem>(item(label)).selected;

Finder get nameField => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  testWidgets('lists the playlists newest first', (tester) async {
    await openApp(tester, h, ['a']);
    await seedPlaylist(tester, h, 'Old', ['a'], now: 1);
    await seedPlaylist(tester, h, 'New', ['a'], now: 2);
    await settleDb(tester);

    expect(
      tester.getTopLeft(find.text('New')).dy,
      lessThan(tester.getTopLeft(find.text('Old')).dy),
    );
    expect(find.text('No playlists yet'), findsNothing);
  });

  testWidgets('says so when there are none', (tester) async {
    await openApp(tester, h, ['a']);

    expect(find.text('No playlists yet'), findsOneWidget);
  });

  testWidgets('opening one highlights only that one', (tester) async {
    await openApp(tester, h, ['a']);
    final old = await seedPlaylist(tester, h, 'Old', ['a'], now: 1);
    await seedPlaylist(tester, h, 'New', ['a'], now: 2);
    await settleDb(tester);
    expect(selected(tester, 'Old'), isFalse);
    expect(selected(tester, 'New'), isFalse);

    await tester.tap(item('Old'));
    await settleDb(tester);

    expect(location(h), '/playlists/$old');
    expect(selected(tester, 'Old'), isTrue);
    expect(selected(tester, 'New'), isFalse);
  });

  testWidgets('the title opens the playlists page', (tester) async {
    await openApp(tester, h, ['a']);

    await tester.tap(find.text('Playlists'));
    await settleDb(tester);

    expect(location(h), '/playlists');
  });

  testWidgets('"+" asks for a name, creates the playlist and opens it', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);

    await tester.tap(find.byTooltip('New playlist'));
    await tester.pumpAndSettle();
    final field = nameField;
    expect(
      tester.widget<TextField>(field).controller!.text,
      'New playlist',
      reason: 'suggested name',
    );
    await tester.enterText(field, 'Road trip');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await settleDb(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(location(h), startsWith('/playlists/'));
    // The page header and the sidebar row.
    expect(find.text('Road trip'), findsNWidgets(2));
    expect(selected(tester, 'Road trip'), isTrue);
  });

  testWidgets('cancelling the name dialog creates nothing', (tester) async {
    await openApp(tester, h, ['a']);

    await tester.tap(find.byTooltip('New playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await settleDb(tester);

    expect(location(h), '/home');
    expect(find.text('No playlists yet'), findsOneWidget);
    final rows = await tester.runAsync(() => h.db.select(h.db.playlists).get());
    expect(rows, isEmpty);
  });

  testWidgets('the collapsed rail keeps "+" and a Playlists entry', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    await seedPlaylist(tester, h, 'Old', ['a']);
    await settleDb(tester);

    h.container.read(sidebarExpandedProvider.notifier).toggle();
    await tester.pumpAndSettle();

    expect(item('Old'), findsNothing);
    expect(find.byIcon(Icons.playlist_add), findsOneWidget);
    final entry = item('Playlists');
    expect(entry, findsOneWidget);
    expect(selected(tester, 'Playlists'), isFalse);

    await tester.tap(entry);
    await settleDb(tester);

    expect(location(h), '/playlists');
    expect(selected(tester, 'Playlists'), isTrue);
  });

  testWidgets('the rail "+" creates a playlist too', (tester) async {
    await openApp(tester, h, ['a']);
    h.container.read(sidebarExpandedProvider.notifier).toggle();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.playlist_add));
    await tester.pumpAndSettle();
    await tester.enterText(nameField, 'Mix');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await settleDb(tester);

    expect(location(h), startsWith('/playlists/'));
  });

  testWidgets('without a library "+" is disabled', (tester) async {
    final none = LibraryHarness(hasDatabase: false);
    await none.pump(tester);

    final add = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.add),
    );
    expect(add.onPressed, isNull);
  });

  testWidgets('in the drawer a playlist closes the drawer and opens', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    final id = await seedPlaylist(tester, h, 'Mix', ['a']);
    await settleDb(tester);
    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(item('Mix'));
    await tester.pumpAndSettle();

    expect(location(h), '/playlists/$id');
    expect(find.byType(SidebarItem), findsNothing, reason: 'drawer closed');
  });

  testWidgets('in the drawer "+" closes it after creating', (tester) async {
    await openApp(tester, h, ['a']);
    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('New playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await settleDb(tester);

    expect(location(h), startsWith('/playlists/'));
    expect(find.byType(SidebarItem), findsNothing, reason: 'drawer closed');
  });
}
