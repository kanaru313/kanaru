import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_album_links.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/shared/artist_modal/artist_modal_actions.dart';
import 'package:kanaru/shared/artist_modal/artist_modal_data.dart';
import 'package:kanaru/shared/artist_modal/artist_modal_links.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_spec.dart';

import 'artist_modal_test_support.dart';

final _l10n = AppLocalizationsEn();

ArtistModalHandlers get _handlers => ArtistModalHandlers(
  goToArtist: () {},
  goToAlbum: (_) {},
  goToFolder: (_) {},
  showInFileManager: (_) {},
  playAll: () {},
  shuffle: () {},
  addToPlaylist: () {},
  addAllToFavorites: () {},
);

List<ContextModalAction> _rows({
  ArtistLinks? links,
  bool showArtist = true,
}) => [
  for (final s in artistModalSections(
    _l10n,
    ArtistModalData(artist: testArtist, links: links, showArtist: showArtist),
    _handlers,
  ))
    ...s,
];

Map<String, ContextModalAction> _byId(ArtistLinks? links) => {
  for (final a in _rows(links: links)) a.id: a,
};

List<String> _ids(ArtistLinks? links, {bool showArtist = true}) => [
  for (final a in _rows(links: links, showArtist: showArtist)) a.id,
];

AlbumFolder _folder(String path, int n) =>
    AlbumFolder(path: path, songCount: n, samplePath: '$path/1.flac');

void main() {
  test('rows in order, links then actions', () {
    expect(_ids(linksOf()), [
      'artist',
      'album',
      'folder',
      'play-all',
      'shuffle',
      'add-to-playlist',
      'edit-tags',
      'advanced',
    ]);
  });

  test('Go to artist is left out on the artist page; otherwise named', () {
    expect(_ids(linksOf(), showArtist: false), isNot(contains('artist')));
    expect(_byId(linksOf())['artist']!.subtitle, 'Ann');
  });

  test('Go to artist shows the name the artist page uses once loaded', () {
    expect(_byId(null)['artist']!.subtitle, 'Ann');
    expect(_byId(linksOf(name: 'Sơn Tùng'))['artist']!.subtitle, 'Sơn Tùng');
  });

  group('albums', () {
    test('loading: greyed row, no subtitle', () {
      final a = _byId(null)['album']!;
      expect(a.enabled, isFalse);
      expect(a.subtitle, isNull);
    });

    test('none: greyed, no album', () {
      final a = _byId(linksOf(own: []))['album']!;
      expect(a.enabled, isFalse);
      expect(a.subtitle, 'No album');
    });

    test('one own album: plain row with its title', () {
      final a = _byId(linksOf())['album']!;
      expect(a.subtitle, 'Own 0');
      expect(a.chips, isNull);
      expect(a.opensPage, isFalse);
      expect(a.onTap, isNotNull);
    });

    test('one appears-on album: plain row too', () {
      final a = _byId(linksOf(own: [], appearsOn: otherAlbums(1)))['album']!;
      expect(a.subtitle, 'Other 0');
      expect(a.chips, isNull);
    });

    // (own, appears on, subtitle)
    for (final (own, other, subtitle) in [
      (2, 0, '2 albums'),
      (0, 2, 'appears on 2'),
      (1, 2, '1 album • appears on 2'),
      (2, 1, '2 albums • appears on 1'),
    ]) {
      test('$own own + $other appears on: wrapped chips, open', () {
        final a = _byId(
          linksOf(own: ownAlbums(own), appearsOn: otherAlbums(other)),
        )['albums']!;
        expect(a.subtitle, subtitle);
        expect(a.chips!.wrap, isTrue);
        expect(a.chips!.initiallyExpanded, isTrue);
        expect(a.opensPage, isFalse);
        expect(
          [for (final c in a.chips!.items) c.label],
          [
            for (final x in [...ownAlbums(own), ...otherAlbums(other)]) x.title,
          ],
        );
      });
    }

    for (final (own, other) in [(4, 0), (0, 4), (2, 2), (12, 0), (5, 7)]) {
      test('$own own + $other appears on: opens a page', () {
        final a = _byId(
          linksOf(own: ownAlbums(own), appearsOn: otherAlbums(other)),
        )['albums']!;
        expect(a.opensPage, isTrue);
        expect(a.chips, isNull);
      });
    }

    test('three in all is still chips, four is a page', () {
      expect(contextModalLinksPageFrom, 4);
      expect(_byId(linksOf(own: ownAlbums(3)))['albums']!.chips, isNotNull);
    });
  });

  group('folders', () {
    test('loading: greyed, no subtitle', () {
      final f = _byId(null)['folder']!;
      expect(f.enabled, isFalse);
      expect(f.subtitle, isNull);
    });

    test('none: row left out', () {
      expect(_ids(linksOf(folders: [])), isNot(contains('folder')));
    });

    test('one: folder name and a Show in file manager button', () {
      final f = _byId(linksOf())['folder']!;
      expect(f.subtitle, 'Rock');
      expect(f.trailing, hasLength(1));
      expect(f.opensPage, isFalse);
    });

    test('three: songs in folders, opens a page', () {
      final f = _byId(
        linksOf(
          folders: [_folder('/m/a', 5), _folder('/m/b', 2), _folder('/m/c', 1)],
        ),
      )['folders']!;
      expect(f.subtitle, '8 songs in 3 folders');
      expect(f.opensPage, isTrue);
      expect(f.trailing, isEmpty);
    });
  });

  test('Edit tags is coming soon, Advanced opens a page', () {
    final byId = _byId(linksOf());
    expect(byId['edit-tags']!.comingSoon, isTrue);
    expect(byId['advanced']!.opensPage, isTrue);
  });
}
