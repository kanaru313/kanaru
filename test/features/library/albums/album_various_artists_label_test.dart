import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_rows.dart';
import 'package:kanaru/features/library/albums/album_header.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/album_artist_label.dart';
import 'package:kanaru/shared/widgets/album_list_tile.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kanaru/shared/widgets/library_grid/album_grid_tile.dart';
import 'package:kanaru/shared/widgets/library_grid/album_tile_data.dart';

const _key = AlbumKey('', 'hits');

AlbumSummary _album({String? artist, bool various = false}) => AlbumSummary(
  key: _key,
  title: 'Hits',
  artist: artist,
  trackCount: 3,
  addedAt: 1,
  variousArtists: various,
);

Future<void> _show(WidgetTester tester, Widget child, Locale locale) =>
    tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SizedBox(width: 900, height: 600, child: child)),
        ),
      ),
    );

/// A cell as high as `heightFor` says, as in the real grid.
Widget _grid(AlbumSummary a) => Builder(
  builder: (context) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 200,
      height: AlbumGridTile.heightFor(context, 200),
      child: AlbumGridTile(data: AlbumTileData.fromSummary(a), onTap: () {}),
    ),
  ),
);

Widget _list(AlbumSummary a) => AlbumListTile(album: a, onTap: () {});

Widget _header(AlbumSummary a) => AlbumHeader(
  albumKey: _key,
  album: a,
  onPlay: () {},
  onShuffle: () {},
  onQueueAction: (_) {},
);

void main() {
  final builders = <String, Widget Function(AlbumSummary)>{
    'grid tile': _grid,
    'list tile': _list,
    'header': _header,
  };
  final locales = {
    const Locale('en'): ('Various artists', 'Unknown artist'),
    const Locale('vi'): ('Nhiều nghệ sĩ', 'Nghệ sĩ không rõ'),
  };

  for (final MapEntry(key: locale, value: (various, unknown))
      in locales.entries) {
    for (final MapEntry(key: name, value: build) in builders.entries) {
      testWidgets('$name in $locale: merged album shows the label', (
        tester,
      ) async {
        await _show(
          tester,
          build(_album(artist: 'ABBA', various: true)),
          locale,
        );
        expect(find.textContaining(various), findsOneWidget);
        expect(find.textContaining('ABBA'), findsNothing);
      });

      testWidgets('$name in $locale: other albums show the name', (
        tester,
      ) async {
        await _show(tester, build(_album(artist: 'ABBA')), locale);
        expect(find.textContaining('ABBA'), findsOneWidget);
        expect(find.textContaining(various), findsNothing);
      });

      testWidgets('$name in $locale: no artist shows unknown', (tester) async {
        await _show(tester, build(_album()), locale);
        expect(find.textContaining(unknown), findsOneWidget);
        expect(find.textContaining(various), findsNothing);
      });
    }
  }

  testWidgets('albumArtistLabel picks label, name, then unknown', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await _show(
      tester,
      Builder(
        builder: (context) {
          l10n = context.l10n;
          return const SizedBox();
        },
      ),
      const Locale('en'),
    );
    expect(
      albumArtistLabel(l10n, artist: 'ABBA', variousArtists: true),
      'Various artists',
    );
    expect(albumArtistLabel(l10n, artist: 'ABBA'), 'ABBA');
    expect(albumArtistLabel(l10n), 'Unknown artist');
    expect(albumArtistLabel(l10n, variousArtists: true), 'Various artists');
  });
}
