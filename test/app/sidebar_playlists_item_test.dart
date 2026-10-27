import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/shell/app_destination.dart';
import 'package:kanaru/app/shell/sidebar/sidebar_item.dart';
import 'package:kanaru/app/shell/sidebar/sidebar_toggle.dart';
import 'package:kanaru/core/settings/display_prefs.dart';
import 'package:material_ui/material_ui.dart';

import '../features/library/browse_test_data.dart' show goTo, location;
import '../features/library/library_test_harness.dart';
import '../features/playlists/playlist_test_data.dart';

Finder item(String label) =>
    find.byWidgetPredicate((w) => w is SidebarItem && w.label == label);

bool selected(WidgetTester tester, String label) =>
    tester.widget<SidebarItem>(item(label)).selected;

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  testWidgets('sits first in its group, right above Favorites', (tester) async {
    await openApp(tester, h, ['a']);

    final playlists = tester.getTopLeft(item('Playlists')).dy;
    final favorites = tester.getTopLeft(item('Favorites')).dy;
    expect(playlists, lessThan(favorites));
    expect(
      tester.getTopLeft(item('Folders')).dy,
      lessThan(playlists),
      reason: 'below the library group',
    );
    final group = visibleSidebarGroups({...SidebarTab.values}).last;
    expect(group.first, AppDestination.playlists);
    expect(group[1], AppDestination.favorites);
  });

  testWidgets('is highlighted on the grid and on a playlist page', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    final id = await seedPlaylist(tester, h, 'Mix', ['a']);
    await settleDb(tester);
    expect(selected(tester, 'Playlists'), isFalse);

    goTo(tester, h, '/playlists');
    await settleDb(tester);
    expect(selected(tester, 'Playlists'), isTrue);

    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);
    expect(selected(tester, 'Playlists'), isTrue);

    goTo(tester, h, '/songs');
    await settleDb(tester);
    expect(selected(tester, 'Playlists'), isFalse);
  });

  testWidgets('stays highlighted on a playlist page with a query string', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    final id = await seedPlaylist(tester, h, 'Mix', ['a']);

    goTo(tester, h, '/playlists/$id?x=1');
    await settleDb(tester);

    expect(location(h), '/playlists/$id?x=1');
    expect(selected(tester, 'Playlists'), isTrue);
  });

  testWidgets('comes back to the last playlist page from another branch', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    final id = await seedPlaylist(tester, h, 'Mix', ['a']);
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);

    await tester.tap(item('Songs'));
    await settleDb(tester);
    expect(location(h), '/songs');

    await tester.tap(item('Playlists'));
    await settleDb(tester);
    expect(location(h), '/playlists/$id');
  });

  testWidgets('goes to the grid when already on a playlist page', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    final id = await seedPlaylist(tester, h, 'Mix', ['a']);
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);

    await tester.tap(item('Playlists'));
    await settleDb(tester);

    expect(location(h), '/playlists');
  });

  testWidgets('the collapsed rail keeps it, labelled by a tooltip', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    final id = await seedPlaylist(tester, h, 'Mix', ['a']);
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);
    h.container.read(sidebarExpandedProvider.notifier).toggle();
    await tester.pumpAndSettle();

    expect(item('Playlists'), findsOneWidget);
    expect(find.text('Playlists'), findsNothing, reason: 'icon only');
    expect(find.byTooltip('Playlists'), findsOneWidget);
    expect(selected(tester, 'Playlists'), isTrue);

    await tester.tap(item('Songs'));
    await settleDb(tester);
    await tester.tap(item('Playlists'));
    await settleDb(tester);

    expect(location(h), '/playlists/$id');
  });

  testWidgets('in the drawer it closes the drawer and opens', (tester) async {
    await openApp(tester, h, ['a']);
    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(item('Playlists'));
    await tester.pumpAndSettle();

    expect(location(h), '/playlists');
    expect(find.byType(SidebarItem), findsNothing, reason: 'drawer closed');
  });
}
