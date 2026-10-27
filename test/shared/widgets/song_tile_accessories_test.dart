import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/core/player/playing_track_path.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/favorite_button.dart';
import 'package:kanaru/shared/widgets/library_row.dart';
import 'package:kanaru/shared/widgets/song_card.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';
import 'package:kanaru/shared/widgets/song_tile_cover.dart';
import 'package:kanaru/shared/widgets/song_tile_placeholder.dart';
import 'package:material_ui/material_ui.dart';

const _song = TrackListItem(
  id: 1,
  path: '/music/a.flac',
  title: 'Song A',
  artist: 'Artist A',
  album: 'Album A',
  durationMs: 61000,
);

const _handleKey = Key('handle');
const _removeKey = Key('remove');

Widget _host(Widget child, {String? playingPath}) => ProviderScope(
  overrides: [playingTrackPathProvider.overrideWithValue(playingPath)],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Column(children: [child])),
  ),
);

void main() {
  testWidgets('handle sits left of the cover, remove right of the heart', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SongTile(
          song: _song,
          onTap: () {},
          leadingAccessory: const SizedBox(key: _handleKey, width: 24),
          trailingAccessory: const SizedBox(key: _removeKey, width: 24),
        ),
      ),
    );
    final handle = tester.getRect(find.byKey(_handleKey));
    final cover = tester.getRect(find.byType(SongTileCover));
    final heart = tester.getRect(find.byType(FavoriteButton));
    final remove = tester.getRect(find.byKey(_removeKey));
    expect(handle.right, lessThanOrEqualTo(cover.left));
    expect(remove.left, greaterThanOrEqualTo(heart.right));
  });

  testWidgets('small accessories do not change the row height', (tester) async {
    await tester.pumpWidget(_host(SongTile(song: _song, onTap: () {})));
    final plain = tester.getSize(find.byType(SongTile)).height;

    await tester.pumpWidget(
      _host(
        SongTile(
          song: _song,
          onTap: () {},
          leadingAccessory: const SizedBox(width: 24, height: 24),
          trailingAccessory: const SizedBox(width: 24, height: 24),
        ),
      ),
    );
    expect(tester.getSize(find.byType(SongTile)).height, plain);
  });

  testWidgets('a tall accessory does not grow the row past its fixed height', (
    tester,
  ) async {
    await tester.pumpWidget(_host(SongTile(song: _song, onTap: () {})));
    final plain = tester.getSize(find.byType(SongTile)).height;

    await tester.pumpWidget(
      _host(
        SongTile(
          song: _song,
          onTap: () {},
          trailingAccessory: const SizedBox(width: 24, height: 48),
        ),
      ),
    );
    expect(tester.getSize(find.byType(SongTile)).height, plain);
  });

  testWidgets('toggling playing keeps the row element with an accessory', (
    tester,
  ) async {
    Widget row(String? playingPath) => _host(
      SongTile(
        song: _song,
        onTap: () {},
        leadingAccessory: const SizedBox(key: _handleKey, width: 24),
      ),
      playingPath: playingPath,
    );

    await tester.pumpWidget(row(null));
    // The row's own InkWell is the outermost one (the heart has another).
    final rowInk = find
        .descendant(of: find.byType(SongTile), matching: find.byType(InkWell))
        .first;
    final inkWell = tester.element(rowInk);
    final handle = tester.element(find.byKey(_handleKey));

    await tester.pumpWidget(row(_song.path));
    expect(tester.element(rowInk), same(inkWell));
    expect(tester.element(find.byKey(_handleKey)), same(handle));
  });

  testWidgets('number and leadingAccessory together are rejected', (
    tester,
  ) async {
    expect(
      () => SongTile(
        song: _song,
        onTap: () {},
        number: '1',
        leadingAccessory: const SizedBox(),
      ),
      throwsAssertionError,
    );
  });

  testWidgets('placeholder inset offsets the cover bar and keeps the height', (
    tester,
  ) async {
    // The cover bar is the only square box in the placeholder.
    Rect coverBar() => tester.getRect(
      find.descendant(
        of: find.byType(SongTilePlaceholder),
        matching: find.byWidgetPredicate(
          (w) =>
              w is SizedBox &&
              w.width == libraryRowCoverSize &&
              w.height == libraryRowCoverSize,
        ),
      ),
    );

    await tester.pumpWidget(_host(const SongTilePlaceholder()));
    final plainLeft = coverBar().left;
    final placeholderHeight = tester
        .getSize(find.byType(SongTilePlaceholder))
        .height;

    await tester.pumpWidget(_host(const SongTilePlaceholder(leadingInset: 24)));
    expect(coverBar().left, plainLeft + 24 + 16);
    expect(
      tester.getSize(find.byType(SongTilePlaceholder)).height,
      placeholderHeight,
    );
  });

  testWidgets('detail replaces the album line and the badge sits above the '
      'duration', (tester) async {
    await tester.pumpWidget(
      _host(
        SongTile(
          song: _song,
          onTap: () {},
          detail: 'Oct 26, 2026 - 21:04',
          badge: const Text('#12', key: Key('badge')),
        ),
      ),
    );
    expect(find.text('Oct 26, 2026 - 21:04'), findsOneWidget);
    expect(find.text('Album A'), findsNothing);
    expect(
      tester.getBottomLeft(find.byKey(const Key('badge'))).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.text('1:01')).dy),
    );

    await tester.pumpWidget(_host(SongTile(song: _song, onTap: () {})));
    expect(find.text('Album A'), findsOneWidget);
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    for (final badge in ['#12', '12 listens']) {
      for (final playing in [false, true]) {
        testWidgets('detail, badge "$badge" and a rank fit the row extent at '
            'scale $scale${playing ? ' (playing)' : ''}', (tester) async {
          late double extent;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                playingTrackPathProvider.overrideWithValue(
                  playing ? _song.path : null,
                ),
              ],
              child: MaterialApp(
                // Desktop shrink-wraps tap targets, so the compact heart is
                // 28 px as in the app.
                theme: ThemeData(platform: TargetPlatform.linux),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, app) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: app!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) {
                      final theme = Theme.of(context);
                      extent = songCardExtent(theme, TextScaler.linear(scale));
                      return Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          height: extent,
                          child: SongTile(
                            song: _song,
                            onTap: () {},
                            detail: 'Oct 26, 2026 - 21:04',
                            leadingAccessory: const SizedBox(
                              width: 32,
                              child: Text('1'),
                            ),
                            badge: Text(
                              badge,
                              maxLines: 1,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);

          final badgeFinder = find.text(badge);
          expect(badgeFinder, findsOneWidget);
          final row = tester.getRect(find.byType(SongTile));
          final badgeRect = tester.getRect(badgeFinder);
          expect(row.height, extent);
          expect(badgeRect.top, greaterThanOrEqualTo(row.top));
          expect(badgeRect.bottom, lessThanOrEqualTo(row.bottom));
          expect(badgeRect.left, greaterThanOrEqualTo(row.left));
          expect(badgeRect.right, lessThanOrEqualTo(row.right));
          // The badge is a direct child of the trailing column.
          final column = find
              .ancestor(of: badgeFinder, matching: find.byType(Column))
              .first;
          expect(tester.getSize(column).height, lessThanOrEqualTo(extent));
        });
      }
    }
  }
}
