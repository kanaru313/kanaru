import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/database/playlist_page_queries.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/features/playlists/playlists_grid.dart';
import 'package:kanaru/features/playlists/playlists_list.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../library/browse_test_data.dart';
import '../../library/library_test_harness.dart';
import '../playlist_test_data.dart';
import 'playlist_modal_test_support.dart';

void main() {
  late LibraryHarness h;
  late List<PlaylistSummary> opened;
  setUp(() {
    h = LibraryHarness();
    opened = [];
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget Function(List<PlaylistCard> cards) build,
  ) async {
    await insertTracks(tester, h, const [TestTrack('a')]);
    final id = await seedPlaylist(tester, h, 'Mix', ['a']);
    await h.pump(tester, hasRoots: true);
    tester.view.physicalSize = const Size(1000, 800);
    final head = await tester.runAsync(() => h.db.playlistPageHead(id));
    final cards = [PlaylistCard(head!.playlist, head.coverKeys)];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Scaffold(body: build(cards)),
              ),
            ],
          ),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget grid(List<PlaylistCard> c) =>
      PlaylistsGrid(cards: c, onOpen: opened.add);
  Widget list(List<PlaylistCard> c) =>
      PlaylistsList(cards: c, onOpen: opened.add);

  void expectModal() {
    expect(modalAction('play-all'), findsOneWidget);
    expect(opened, isEmpty);
  }

  testWidgets('a grid card opens the modal on a right click', (tester) async {
    await pumpScreen(tester, grid);
    await tester.tap(find.text('Mix'), buttons: kSecondaryButton);
    await settleModal(tester);
    expectModal();
  });

  testWidgets('a grid card opens the modal on a long press', (tester) async {
    await pumpScreen(tester, grid);
    await tester.longPress(find.text('Mix'));
    await settleModal(tester);
    expectModal();
  });

  for (final (name, shift, key) in [
    ('the Menu key', false, LogicalKeyboardKey.contextMenu),
    ('Shift+F10', true, LogicalKeyboardKey.f10),
  ]) {
    testWidgets('a grid card opens the modal on $name', (tester) async {
      await pumpScreen(tester, grid);
      // The nearest focus node above the card's text is the ink well's.
      Focus.of(tester.element(find.text('Mix'))).requestFocus();
      await tester.pump();
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settleModal(tester);
      expectModal();
    });
  }

  testWidgets('a grid card has no more button', (tester) async {
    await pumpScreen(tester, grid);
    expect(find.byIcon(AppIcons.more), findsNothing);
  });

  testWidgets('a list row opens the modal from the more button', (
    tester,
  ) async {
    await pumpScreen(tester, list);
    await tester.tap(find.byIcon(AppIcons.more));
    await settleModal(tester);
    expectModal();
  });

  testWidgets('a list row opens the modal on a right click', (tester) async {
    await pumpScreen(tester, list);
    await tester.tap(find.text('Mix'), buttons: kSecondaryButton);
    await settleModal(tester);
    expectModal();
  });

  testWidgets('a tap on a list row still opens the playlist', (tester) async {
    await pumpScreen(tester, list);
    await tester.tap(find.text('Mix'));
    expect(opened, hasLength(1));
  });
}
