import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/core/player/playing_track_path.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/favorite_button.dart';
import 'package:kanaru/shared/widgets/library_row.dart';
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
}
