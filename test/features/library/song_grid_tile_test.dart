import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/database/playlist_providers.dart';
import 'package:kanaru/core/player/playing_track_path.dart';
import 'package:kanaru/core/settings/library_sort.dart';
import 'package:kanaru/features/library/library_view_modes.dart';
import 'package:kanaru/features/library/songs/song_grid_tile.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/cover_art.dart';
import 'package:kanaru/shared/widgets/favorite_button.dart';
import 'package:kanaru/shared/widgets/song_card.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';
import 'list_view_modes_override.dart';

TrackListItem _song({String? album = 'Album', int? durationMs = 262000}) =>
    TrackListItem(
      id: 1,
      path: '/music/a.flac',
      title: 'Song A',
      artist: 'Artist A',
      album: album,
      durationMs: durationMs,
    );

void main() {
  late LibraryDatabase db;
  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget host(
    Widget child, {
    String? playingPath,
    double scale = 1,
    double? width,
    bool storedFavorites = false,
  }) => ProviderScope(
    overrides: [
      libraryDatabaseProvider.overrideWithValue(db),
      if (!storedFavorites)
        favoritePathsProvider.overrideWith((ref) => Stream.value(const {})),
      playingTrackPathProvider.overrideWithValue(playingPath),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: width == null
                  ? child
                  : SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    ),
  );

  Finder card() => find
      .descendant(
        of: find.byType(SongGridTile),
        matching: find.byType(Material),
      )
      .first;

  group('detail line', () {
    for (final (album, durationMs, expected) in [
      ('Album', 262000, 'Album • 4:22'),
      (null, 262000, '4:22'),
      ('Album', null, 'Album'),
      ('', 262000, '4:22'),
    ]) {
      testWidgets('album $album, length $durationMs shows "$expected"', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            SizedBox(
              width: 200,
              height: 400,
              child: SongGridTile(
                song: _song(album: album, durationMs: durationMs),
                onTap: () {},
              ),
            ),
          ),
        );
        expect(find.text(expected), findsOneWidget);
        expect(find.text('Song A'), findsOneWidget);
        expect(find.text('Artist A'), findsOneWidget);
      });
    }
  });

  group('no overflow', () {
    for (final scale in [1.0, 1.15, 1.3, 1.5, 2.0]) {
      for (final columns in [1, 3, 6]) {
        testWidgets('scale $scale, $columns columns', (tester) async {
          // Same width rule as the Songs grid: columns of at most 200 px.
          final width = columns == 1 ? 180.0 : columns * 190.0;
          late SliverGridDelegate delegate;
          await tester.pumpWidget(
            host(
              Builder(
                builder: (context) {
                  delegate = songGridDelegate(context, width);
                  final fixed =
                      delegate as SliverGridDelegateWithFixedCrossAxisCount;
                  return SizedBox(
                    width: width,
                    height: fixed.mainAxisExtent,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: delegate,
                      itemCount: columns,
                      itemBuilder: (_, i) => SongGridTile(
                        song: _song(album: 'A long album name $i' * 3),
                        onTap: () {},
                      ),
                    ),
                  );
                },
              ),
              scale: scale,
              width: width,
            ),
          );
          expect(
            (delegate as SliverGridDelegateWithFixedCrossAxisCount)
                .crossAxisCount,
            columns,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('the heart toggles the favorite and does not play', (
    tester,
  ) async {
    var taps = 0;
    await tester.runAsync(() async {
      final root = (await db.addRoots(['/music'], now: 1)).single;
      await db.upsertTracks([
        TracksCompanion.insert(
          rootId: root,
          path: '/music/a.flac',
          mtimeMs: 1,
          sizeBytes: 1,
          title: 'Song A',
          addedAt: 1,
          updatedAt: 1,
          coverKey: const Value(null),
        ),
      ]);
    });
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 200,
          height: 400,
          child: SongGridTile(song: _song(), onTap: () => taps++),
        ),
        storedFavorites: true,
      ),
    );
    await tester.pump();
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).isSelected,
      isFalse,
    );

    await tester.tap(find.byType(FavoriteButton));
    await tester.pump();

    expect(
      tester.widget<IconButton>(find.byType(IconButton)).isSelected,
      isTrue,
    );
    expect(taps, 0);
    // Let the pending write finish before the database closes.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(await tester.runAsync(() => db.isFavorite('/music/a.flac')), isTrue);

    await tester.tap(find.text('Song A'));
    expect(taps, 1);

    // Drop the tree so the database stream's cleanup timer runs.
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('only the playing card is filled with primaryContainer', (
    tester,
  ) async {
    Future<void> pump(String? playing) => tester.pumpWidget(
      host(
        SizedBox(
          width: 200,
          height: 400,
          child: SongGridTile(song: _song(), onTap: () {}),
        ),
        playingPath: playing,
      ),
    );
    await pump('/music/other.flac');
    final colors = Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
    expect(tester.widget<Material>(card()).color, songCardColor(colors));
    expect(
      tester.widget<Text>(find.text('Song A')).style?.color,
      isNot(colors.onPrimaryContainer),
    );

    await pump('/music/a.flac');
    expect(
      tester.widget<Material>(card()).color,
      songCardColor(colors, playing: true),
    );
    expect(tester.widget<Material>(card()).color, colors.primaryContainer);
    for (final text in ['Song A', 'Artist A', 'Album • 4:22']) {
      expect(
        tester.widget<Text>(find.text(text)).style?.color,
        colors.onPrimaryContainer,
      );
    }
  });

  testWidgets('the placeholder card has the rect of a tile card', (
    tester,
  ) async {
    Future<Rect> rectOf(Widget tile) async {
      await tester.pumpWidget(
        host(SizedBox(width: 200, height: 400, child: tile)),
      );
      return tester.getRect(
        find
            .descendant(
              of: find.byType(Padding),
              matching: find.byType(Material),
            )
            .first,
      );
    }

    final tile = await rectOf(SongGridTile(song: _song(), onTap: () {}));
    final placeholder = await rectOf(const SongGridTilePlaceholder());
    // In a grid cell both get the same tight box, so the cards coincide.
    expect(placeholder, tile);
  });

  testWidgets(
    'the first cover in the Songs grid starts 32 px from the page edge',
    (tester) async {
      final h = LibraryHarness(overrides: [listViewModesOverride]);
      await openWithTracks(tester, h, const [
        TestTrack('a', artist: 'Ann', album: 'Al'),
      ], location: '/songs');
      await tester.tap(find.byTooltip('List'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(h.container.read(libraryViewModesProvider).songs, AlbumsView.grid);

      final tile = tester.getRect(find.byType(SongGridTile).first);
      final cardRect = tester.getRect(
        find
            .descendant(
              of: find.byType(SongGridTile).first,
              matching: find.byType(Material),
            )
            .first,
      );
      final cover = tester.getTopLeft(
        find
            .descendant(
              of: find.byType(SongGridTile).first,
              matching: find.byType(CoverArt),
            )
            .first,
      );
      final grid = tester.getRect(
        find
            .ancestor(
              of: find.byType(SongGridTile).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(cardRect.left, tile.left + 4);
      expect(cover.dx - grid.left, 32);
    },
  );
}
