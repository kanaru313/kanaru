import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/shell/sidebar/sidebar_item.dart';
import 'package:kanaru/app/shell/sidebar/sidebar_playlists_section.dart';
import 'package:kanaru/app/shell/sidebar/sidebar_toggle.dart';
import 'package:material_ui/material_ui.dart';

import '../library/browse_test_data.dart' show goTo, location;
import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

Finder item(String label) =>
    find.byWidgetPredicate((w) => w is SidebarItem && w.label == label);

/// The expanded "Playlists" title.
Finder get title => find.descendant(
  of: find.byType(SidebarPlaylistsSection),
  matching: find.text('Playlists'),
);

Color? titleColor(WidgetTester tester) =>
    tester.widget<Text>(title).style?.color;

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  testWidgets('the title comes back to the last playlist page', (tester) async {
    await openApp(tester, h, ['a']);
    final id = await seedPlaylist(tester, h, 'Mix', ['a']);
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);

    await tester.tap(item('Songs'));
    await settleDb(tester);
    expect(location(h), '/songs');

    await tester.tap(title);
    await settleDb(tester);
    expect(location(h), '/playlists/$id');
  });

  testWidgets('the title goes to the grid when already in playlists', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    final id = await seedPlaylist(tester, h, 'Mix', ['a']);
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);

    await tester.tap(title);
    await settleDb(tester);

    expect(location(h), '/playlists');
  });

  testWidgets('the rail entry comes back to the last playlist page', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    final id = await seedPlaylist(tester, h, 'Mix', ['a']);
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);
    h.container.read(sidebarExpandedProvider.notifier).toggle();
    await tester.pumpAndSettle();

    await tester.tap(item('Songs'));
    await settleDb(tester);
    await tester.tap(item('Playlists'));
    await settleDb(tester);

    expect(location(h), '/playlists/$id');
  });

  testWidgets('the title is highlighted on the grid and on a playlist page', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    final id = await seedPlaylist(tester, h, 'Mix', ['a']);
    await settleDb(tester);
    final muted = titleColor(tester);

    goTo(tester, h, '/playlists');
    await settleDb(tester);
    final onGrid = titleColor(tester);
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);
    final onPage = titleColor(tester);
    goTo(tester, h, '/songs');
    await settleDb(tester);

    expect(onGrid, isNot(muted));
    expect(onPage, onGrid);
    expect(titleColor(tester), muted);
  });

  testWidgets('the title is a selected button for screen readers', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    goTo(tester, h, '/playlists');
    await settleDb(tester);

    final flags = tester
        .getSemantics(find.ancestor(of: title, matching: find.byType(InkWell)))
        .getSemanticsData()
        .flagsCollection;
    expect(flags.isButton, isTrue);
    expect(flags.isSelected, Tristate.isTrue);
  });

  testWidgets('a page id with a leading zero still marks its row', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    final id = await seedPlaylist(tester, h, 'Mix', ['a']);
    goTo(tester, h, '/playlists/0$id');
    await settleDb(tester);

    expect(tester.widget<SidebarItem>(item('Mix')).selected, isTrue);
  });
}
