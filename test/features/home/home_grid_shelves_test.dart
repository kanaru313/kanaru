import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/play_history_writes.dart';
import 'package:kanaru/features/home/home_screen.dart';
import 'package:kanaru/features/home/home_tile_metrics.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/card_shelf.dart';
import 'package:kanaru/shared/widgets/cover_art.dart';
import 'package:kanaru/shared/widgets/favorite_button.dart';
import 'package:kanaru/shared/widgets/library_grid/song_grid_tile.dart';
import 'package:material_ui/material_ui.dart';

import 'home_test_harness.dart';

void main() {
  final now = DateTime(2026, 10, 24, 12);

  /// [count] played songs, enough to overflow the shelf at 1280 px.
  Future<HomeHarness> played(int count) async {
    final h = HomeHarness(now: now);
    for (var i = 0; i < count; i++) {
      final p = '/s$i';
      await h.addTrack(p, artist: 'Ann', album: 'Alb');
      await h.db.insertLibraryPlay(
        path: p,
        playedAt: now.millisecondsSinceEpoch - i * 1000,
        listenedMs: 200000,
      );
    }
    return h;
  }

  Future<void> open(
    WidgetTester tester,
    HomeHarness h, {
    double width = 1280,
    double textScale = 1,
  }) => h.pump(
    tester,
    const HomeScreen(),
    width: width,
    height: 2400,
    textScale: textScale,
  );

  group('song shelves', () {
    testWidgets('draw grid cards with a heart each', (tester) async {
      final h = await played(3);
      await open(tester, h);
      final tiles = find.byType(SongGridTile);
      expect(tiles, findsWidgets);
      expect(
        find.descendant(of: tiles.first, matching: find.byType(FavoriteButton)),
        findsOneWidget,
      );
    });

    testWidgets('do not overflow at x2 text in a narrow window', (
      tester,
    ) async {
      final h = await played(3);
      await open(tester, h, width: 480, textScale: 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keep the cover 8 px down and the arrow centered on it', (
      tester,
    ) async {
      final h = await played(12);
      await open(tester, h);
      final tile = tester.getRect(find.byType(SongGridTile).first);
      final cover = tester.getRect(
        find.descendant(
          of: find.byType(SongGridTile).first,
          matching: find.byType(CoverArt),
        ),
      );
      expect(cover.top, tile.top + homeGridCardInset);
      expect(cover.height, homeGridCardCoverSize);
      final shelf = find.ancestor(
        of: find.byType(SongGridTile).first,
        matching: find.byType(CardShelf),
      );
      final arrow = tester.getCenter(
        find
            .descendant(of: shelf, matching: find.byIcon(AppIcons.chevronRight))
            .first,
      );
      expect(arrow.dy, closeTo(cover.center.dy, 0.5));
    });

    testWidgets('tint the playing song with primaryContainer', (tester) async {
      final h = await played(3);
      await open(tester, h);
      await tester.tap(find.text('T /s0').first);
      await tester.pumpAndSettle();
      final scheme = Theme.of(tester.element(find.byType(SongGridTile).first))
          .colorScheme;
      final tinted = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byType(SongGridTile),
              matching: find.byType(Material),
            ),
          )
          .where((m) => m.color == scheme.primaryContainer);
      expect(tinted, isNotEmpty);
    });
  });
}
