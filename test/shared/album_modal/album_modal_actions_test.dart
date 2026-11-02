import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_album_links.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/shared/album_modal/album_modal_actions.dart';
import 'package:kanaru/shared/album_modal/album_modal_data.dart';
import 'package:kanaru/shared/folder_links/folder_paths.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_spec.dart';

import 'album_modal_test_support.dart';

final _l10n = AppLocalizationsEn();

AlbumModalHandlers get _handlers => AlbumModalHandlers(
  goToAlbum: () {},
  goToArtist: (_) {},
  goToFolder: (_) {},
  showInFileManager: (_) {},
  playAll: () {},
  shuffle: () {},
  addToPlaylist: () {},
  addAllToFavorites: () {},
);

List<List<ContextModalAction>> _sections({
  AlbumLinks? links,
  bool showAlbum = true,
  String? pageArtistKey,
}) => albumModalSections(
  _l10n,
  AlbumModalData(
    album: testAlbum,
    links: links,
    showAlbum: showAlbum,
    pageArtistKey: pageArtistKey,
  ),
  _handlers,
);

Map<String, ContextModalAction> _byId(
  AlbumLinks? links, {
  bool showAlbum = true,
  String? pageArtistKey,
}) => {
  for (final s in _sections(
    links: links,
    showAlbum: showAlbum,
    pageArtistKey: pageArtistKey,
  ))
    for (final a in s) a.id: a,
};

List<String> _ids(AlbumLinks? links, {bool showAlbum = true}) => [
  for (final s in _sections(links: links, showAlbum: showAlbum))
    for (final a in s) a.id,
];

AlbumFolder _folder(String path, int n) =>
    AlbumFolder(path: path, songCount: n, samplePath: '$path/1.flac');

void main() {
  test('rows in order, links then actions', () {
    expect(_ids(linksOf()), [
      'album',
      'artist',
      'folder',
      'play-all',
      'shuffle',
      'add-to-playlist',
      'edit-tags',
      'advanced',
    ]);
  });

  test('Go to album is left out on the album page; otherwise titled', () {
    expect(_ids(linksOf(), showAlbum: false), isNot(contains('album')));
    expect(_byId(linksOf())['album']!.subtitle, 'Al');
  });

  group('artists', () {
    test('loading: greyed row with the header artist', () {
      final a = _byId(null)['artist']!;
      expect(a.enabled, isFalse);
      expect(a.subtitle, 'Ann');
    });

    test('none: greyed, no artist', () {
      final a = _byId(linksOf(artists: []))['artist']!;
      expect(a.enabled, isFalse);
      expect(a.subtitle, 'No artist');
    });

    test('one: plain row with the name', () {
      final a = _byId(linksOf())['artist']!;
      expect(a.subtitle, 'Ann');
      expect(a.chips, isNull);
      expect(a.opensPage, isFalse);
      expect(a.onTap, isNotNull);
    });

    for (final n in [2, 3]) {
      test('$n: wrapped chips, open', () {
        final a = _byId(
          linksOf(artists: artistsOf([for (var i = 0; i < n; i++) 'A$i'])),
        )['artists']!;
        expect(a.subtitle, '$n artists');
        expect(a.chips!.wrap, isTrue);
        expect(a.chips!.initiallyExpanded, isTrue);
        expect(a.chips!.items, hasLength(n));
      });
    }

    for (final n in [4, 12]) {
      test('$n: opens a page', () {
        final a = _byId(
          linksOf(artists: artistsOf([for (var i = 0; i < n; i++) 'A$i'])),
        )['artists']!;
        expect(a.subtitle, '$n artists');
        expect(a.opensPage, isTrue);
        expect(a.chips, isNull);
      });
    }
  });

  group("artists on an artist's page", () {
    test('the page artist alone: no Go to artist row', () {
      final byId = _byId(linksOf(), pageArtistKey: 'ann');
      expect(byId.keys, isNot(contains('artist')));
      expect(byId.keys, isNot(contains('artists')));
      expect(byId.keys, contains('folder'));
    });

    test('with one other artist: a plain row naming the other', () {
      final a = _byId(
        linksOf(artists: artistsOf(['Ann', 'Bob'])),
        pageArtistKey: 'ann',
      )['artist']!;
      expect(a.subtitle, 'Bob');
      expect(a.chips, isNull);
    });

    test('the count and the page threshold use the other artists', () {
      final a = _byId(
        linksOf(artists: artistsOf(['Ann', 'B', 'C', 'D'])),
        pageArtistKey: 'ann',
      )['artists']!;
      expect(a.subtitle, '3 artists');
      expect(a.opensPage, isFalse);
      expect([for (final c in a.chips!.items) c.label], ['B', 'C', 'D']);
    });

    test('loading: still the greyed row', () {
      final a = _byId(null, pageArtistKey: 'ann')['artist']!;
      expect(a.enabled, isFalse);
    });

    test('no artist: still the greyed No artist row', () {
      final a = _byId(linksOf(artists: []), pageArtistKey: 'ann')['artist']!;
      expect(a.subtitle, 'No artist');
    });

    test('linkedArtists leaves the page artist out', () {
      final data = AlbumModalData(
        album: testAlbum,
        links: linksOf(artists: artistsOf(['Ann', 'Bob'])),
        pageArtistKey: 'ann',
      );
      expect(data.linkedArtists, artistsOf(['Bob']));
      expect(
        AlbumModalData(album: testAlbum, links: null).linkedArtists,
        isNull,
      );
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

    test('many: songs in folders, opens a page', () {
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

  test('folder helpers', () {
    expect(folderName('/music/Rock'), 'Rock');
    expect(folderName('/'), '/');
    expect(parentPath('/music/Rock'), '/music');
    expect(parentPath('/music'), '');
  });
}
