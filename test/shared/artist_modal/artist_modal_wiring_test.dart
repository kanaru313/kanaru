import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/play_history_writes.dart';
import 'package:kanaru/core/search/search_prefs_provider.dart';
import 'package:kanaru/features/home/home_screen.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/artist_modal/artist_more_button.dart';
import 'package:kanaru/shared/widgets/artist_tile.dart';
import 'package:kanaru/shared/widgets/library_grid/artist_grid_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/home/home_test_harness.dart';
import '../../features/library/browse_test_data.dart';
import '../../features/library/library_test_harness.dart';
import '../../features/search/search_test_data.dart';
import 'artist_modal_test_support.dart';

const _tracks = [
  TestTrack('a1', artist: 'Ann', album: 'Alpha', track: 1),
  TestTrack('a2', artist: 'Ann', album: 'Alpha', track: 2),
];

/// Row only the artist modal has; the old popup lacked it.
Finder get _modal => find.bySemanticsLabel('Artist options');

Future<void> _pumpTile(WidgetTester tester, {bool withQueue = true}) =>
    tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ArtistTile(
              artist: testArtist,
              onTap: () {},
              onPlay: () {},
              onQueueAction: withQueue ? (_) {} : null,
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets('an artist grid tile opens the artist modal', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/artists');
    expect(find.byType(ArtistGridTile), findsOneWidget);

    await tester.tap(find.text('Ann'), buttons: kSecondaryButton);
    await settleArtistModal(tester);

    expect(_modal, findsWidgets);
  });

  testWidgets('the list row shows ⋮ only with a queue action', (tester) async {
    await _pumpTile(tester);
    expect(find.byType(ArtistMoreButton), findsOneWidget);
    await _pumpTile(tester, withQueue: false);
    expect(find.byType(ArtistMoreButton), findsNothing);
  });

  testWidgets('a tap on ⋮ opens the modal; Enter focuses its first row', (
    tester,
  ) async {
    await _pumpTile(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleArtistModal(tester);

    expect(_modal, findsWidgets);
    final ctx = FocusManager.instance.primaryFocus?.context;
    expect(
      find.descendant(
        of: _modal.first,
        matching: find.byElementPredicate((e) => e == ctx),
      ),
      findsWidgets,
    );
  });

  testWidgets('a Home artist tile opens the artist modal with the length', (
    tester,
  ) async {
    final h = HomeHarness();
    await h.addTrack('/a', artist: 'Ann', album: 'Alpha', durationMs: 180000);
    await h.db.insertLibraryPlay(
      path: '/a',
      playedAt: DateTime.now().millisecondsSinceEpoch,
      listenedMs: 200000,
    );
    await h.pump(tester, const HomeScreen(), height: 2400);

    await tester.tap(
      find.descendant(
        of: find.descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(ArtistGridTile),
        ),
        matching: find.text('Ann'),
      ),
      buttons: kSecondaryButton,
    );
    await settleArtistModal(tester);

    expect(_modal, findsWidgets);
    expect(find.text('1 album • 1 song • 3 min'), findsOneWidget);
  });

  testWidgets('a search artist row opens the modal and saves the history', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'son tung');
    final row = find.descendant(
      of: find.byType(ArtistTile),
      matching: find.text('Sơn Tùng M-TP'),
    );
    expect(
      find.descendant(
        of: find.byType(ArtistTile),
        matching: find.byType(ArtistMoreButton),
      ),
      findsOneWidget,
    );

    await tester.tap(row, buttons: kSecondaryButton);
    await settleArtistModal(tester);
    expect(_modal, findsWidgets);

    await tester.tap(find.byKey(const ValueKey('artist-modal-add-to-queue')));
    await settleIo(tester, h);

    expect(h.container.read(searchPrefsProvider).value!.history, ['son tung']);
    expect(queuedTitles(h), ['Lạc Trôi', 'Chạy Ngay Đi']);
  });
}
