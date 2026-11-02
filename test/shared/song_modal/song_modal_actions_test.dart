import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_track_links.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/song_modal/song_modal_actions.dart';
import 'package:kanaru/shared/song_modal/song_modal_advanced_page.dart';
import 'package:kanaru/shared/song_modal/song_modal_data.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_nav.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_spec.dart';

final _l10n = AppLocalizationsEn();

const _song = TrackListItem(
  id: 1,
  path: '/music/Rock/a.flac',
  title: 'A',
  artist: 'Ann',
  album: 'Al',
);

typedef _Artists = List<({String key, String name})>;

_Artists _names(List<String> names) => [
  for (final n in names) (key: n.toLowerCase(), name: n),
];

SongModalHandlers get _handlers => SongModalHandlers(
  goToAlbum: () {},
  goToArtist: (_) {},
  goToFolder: () {},
  showInFileManager: () {},
  addToPlaylist: () {},
  setFavorite: (_) {},
  findLyrics: () {},
);

/// The actions by id, over the sections of [data].
Map<String, ContextModalAction> _byId(SongModalData data) => {
  for (final section in songModalSections(_l10n, data, _handlers))
    for (final action in section) action.id: action,
};

SongModalData _data({
  TrackListItem song = _song,
  TrackLinks? links,
  bool? isFavorite = false,
  bool hasLibrary = true,
  bool canFindLyrics = true,
  bool showAlbum = true,
  String? pageArtistKey,
  bool showFolder = true,
}) => SongModalData(
  song: song,
  links: links,
  isFavorite: isFavorite,
  hasLibrary: hasLibrary,
  canFindLyrics: canFindLyrics,
  showAlbum: showAlbum,
  pageArtistKey: pageArtistKey,
  showFolder: showFolder,
);

TrackLinks _links({
  _Artists? artists,
  _Artists albumArtists = const [],
  AlbumKey? album = const AlbumKey('ann', 'al'),
}) => TrackLinks(
  artists: artists ?? _names(['Ann']),
  album: album,
  albumArtists: albumArtists,
);

void main() {
  group('Go to album', () {
    test('is enabled with the album as subtitle', () {
      final a = _byId(_data(links: _links()))['album']!;
      expect(a.enabled, isTrue);
      expect(a.subtitle, 'Al');
    });

    test('is left out on the album page', () {
      expect(
        _byId(_data(links: _links(), showAlbum: false)),
        isNot(contains('album')),
      );
    });

    test('is disabled saying No album when the song has none', () {
      final a = _byId(
        _data(
          song: const TrackListItem(id: 1, path: '/m/a.flac', title: 'A'),
          links: _links(album: null),
        ),
      )['album']!;
      expect(a.enabled, isFalse);
      expect(a.subtitle, 'No album');
    });

    test('is disabled while the links load', () {
      expect(_byId(_data())['album']!.enabled, isFalse);
    });
  });

  group('Go to artist', () {
    test('without an artist is disabled', () {
      final a = _byId(_data(links: _links(artists: [])))['artist']!;
      expect(a.enabled, isFalse);
      expect(a.subtitle, 'No artist');
    });

    test('with one artist is a plain row naming the artist', () {
      final a = _byId(_data(links: _links()))['artist']!;
      expect(a.enabled, isTrue);
      expect(a.chips, isNull);
      expect(a.subtitle, 'Ann');
    });

    test('with two artists folds chips, open', () {
      final a = _byId(
        _data(links: _links(artists: _names(['Ann', 'Bob']))),
      )['artists']!;
      expect(a.subtitle, '2 artists');
      expect([for (final c in a.chips!.items) c.label], ['Ann', 'Bob']);
      expect(a.chips!.initiallyExpanded, isTrue);
    });

    test('opens its chips below $artistsOpenBelow artists only', () {
      for (final count in [artistsOpenBelow - 1, artistsOpenBelow, 7]) {
        final names = [for (var i = 0; i < count; i++) 'Artist$i'];
        final a = _byId(
          _data(links: _links(artists: _names(names))),
        )['artists']!;
        expect(a.chips!.items, hasLength(count));
        expect(
          a.chips!.initiallyExpanded,
          count < artistsOpenBelow,
          reason: '$count artists',
        );
      }
    });
  });

  group('Go to album artist', () {
    test('is left out when it is the song artist', () {
      final all = _byId(_data(links: _links(albumArtists: _names(['Ann']))));
      expect(all.keys, isNot(contains('album-artist')));
    });

    test('is shown when the album artist is somebody else', () {
      final a = _byId(
        _data(links: _links(albumArtists: _names(['Bob']))),
      )['album-artist']!;
      expect(a.subtitle, 'Bob');
    });

    test('is shown when only some album artists are song artists', () {
      final a = _byId(
        _data(links: _links(albumArtists: _names(['Ann', 'Bob']))),
      )['album-artists']!;
      expect(a.chips!.items, hasLength(2));
    });

    test('is left out when no album artist has a page', () {
      expect(_byId(_data(links: _links())), isNot(contains('album-artist')));
    });
  });

  group('Go to folder', () {
    test('names the folder and offers the file manager', () {
      final a = _byId(_data(links: _links()))['folder']!;
      expect(a.subtitle, 'Rock');
      expect(a.trailing, hasLength(1));
      expect(a.trailing.single.tooltip, 'Show in file manager');
    });

    test('is left out for a song with no local path', () {
      const remote = TrackListItem(
        id: 1,
        path: 'https://example.org/a.mp3',
        title: 'A',
      );
      expect(_byId(_data(song: remote)), isNot(contains('folder')));
    });
  });

  group("on an artist's page", () {
    // pageArtistKey no longer filters out the page artist — all artists show.

    test('Go to artist shows the page artist too (single artist)', () {
      final a = _byId(_data(links: _links(), pageArtistKey: 'ann'))['artist']!;
      expect(a.subtitle, 'Ann');
      expect(a.enabled, isTrue);
    });

    test('Go to artist shows every artist including the page artist', () {
      final a = _byId(
        _data(
          links: _links(artists: _names(['Ann', 'Bob'])),
          pageArtistKey: 'ann',
        ),
      )['artists']!;
      expect([for (final c in a.chips!.items) c.label], ['Ann', 'Bob']);
    });

    test('a page of another artist keeps every artist', () {
      final a = _byId(
        _data(
          links: _links(artists: _names(['Ann', 'Bob'])),
          pageArtistKey: 'cy',
        ),
      )['artists']!;
      expect([for (final c in a.chips!.items) c.label], ['Ann', 'Bob']);
    });

    test('Go to artist stays greyed out while the links load', () {
      final a = _byId(_data(pageArtistKey: 'ann'))['artist']!;
      expect(a.enabled, isFalse);
      expect(a.subtitle, 'Ann');
    });

    test('a song without artists keeps the greyed No artist row', () {
      final a = _byId(
        _data(
          links: _links(artists: []),
          pageArtistKey: 'ann',
        ),
      )['artist']!;
      expect(a.enabled, isFalse);
      expect(a.subtitle, 'No artist');
    });

    test('Go to album artist shows all album artists including the page artist', () {
      final a = _byId(
        _data(
          links: _links(albumArtists: _names(['Ann', 'Bob'])),
          pageArtistKey: 'ann',
        ),
      )['album-artists']!;
      expect([for (final c in a.chips!.items) c.label], ['Ann', 'Bob']);
    });

    test(
      'Go to album artist shows the page artist when it is an album-only artist',
      () {
        final all = _byId(
          _data(
            links: _links(
              artists: _names(['Bob']),
              albumArtists: _names(['Ann']),
            ),
            pageArtistKey: 'ann',
          ),
        );
        expect(all['album-artist']!.subtitle, 'Ann');
        expect(all['artist']!.subtitle, 'Bob');
      },
    );

    test('album artists that are all song artists still hide the row', () {
      // Song by Ann and Bob, album by Ann and Bob: no separate album artist row.
      final all = _byId(
        _data(
          links: _links(
            artists: _names(['Ann', 'Bob']),
            albumArtists: _names(['Ann', 'Bob']),
          ),
          pageArtistKey: 'ann',
        ),
      );
      expect(all.keys, isNot(contains('album-artist')));
      expect(all.keys, isNot(contains('album-artists')));
    });
  });

  group('on a folder page', () {
    test('has no Go to folder but a Show in file manager row', () {
      final calls = <String>[];
      final handlers = SongModalHandlers(
        goToAlbum: () {},
        goToArtist: (_) {},
        goToFolder: () {},
        showInFileManager: () => calls.add('show'),
        addToPlaylist: () {},
        setFavorite: (_) {},
        findLyrics: () {},
      );
      final all = {
        for (final section in songModalSections(
          _l10n,
          _data(links: _links(), showFolder: false),
          handlers,
        ))
          for (final action in section) action.id: action,
      };
      expect(all.keys, isNot(contains('folder')));
      final row = all['show-in-file-manager']!;
      expect(row.label, 'Show in file manager');
      expect(row.icon, AppIcons.folderOpen);
      expect(row.trailing, isEmpty);
      row.onTap!(
        ContextModalNav(
          push: (_) {},
          pop: () {},
          close: ([_]) => calls.add('close'),
        ),
      );
      expect(calls, ['close', 'show']);
    });

    test('a song with no local path has neither row', () {
      const remote = TrackListItem(
        id: 1,
        path: 'https://example.org/a.mp3',
        title: 'A',
      );
      final all = _byId(_data(song: remote, showFolder: false));
      expect(all.keys, isNot(contains('folder')));
      expect(all.keys, isNot(contains('show-in-file-manager')));
    });

    test('elsewhere there is no Show in file manager row', () {
      expect(
        _byId(_data(links: _links())),
        isNot(contains('show-in-file-manager')),
      );
    });
  });

  group('favorite', () {
    test('adds when the song is not a favorite', () {
      final a = _byId(_data())['favorite']!;
      expect(a.label, 'Add to favorites');
      expect(a.enabled, isTrue);
    });

    test('removes when it is', () {
      expect(
        _byId(_data(isFavorite: true))['favorite']!.label,
        'Remove from favorites',
      );
    });

    test('is a disabled placeholder until the state is read', () {
      expect(_byId(_data(isFavorite: null))['favorite']!.enabled, isFalse);
    });

    test('is left out without a library', () {
      expect(_byId(_data(hasLibrary: false)), isNot(contains('favorite')));
    });

    test('asks for the opposite of the current state', () {
      final asked = <bool>[];
      final handlers = SongModalHandlers(
        goToAlbum: () {},
        goToArtist: (_) {},
        goToFolder: () {},
        showInFileManager: () {},
        addToPlaylist: () {},
        setFavorite: asked.add,
        findLyrics: () {},
      );
      final action = songModalSections(
        _l10n,
        _data(isFavorite: true),
        handlers,
      ).expand((s) => s).firstWhere((a) => a.id == 'favorite');
      action.onTap!(ContextModalNav(push: (_) {}, pop: () {}, close: ([_]) {}));
      expect(asked, [false]);
    });
  });

  group('other rows', () {
    test('Edit tags is coming soon and Advanced opens a page', () {
      final all = _byId(_data(links: _links()));
      expect(all['edit-tags']!.comingSoon, isTrue);
      expect(all, isNot(contains('song-info')));
      expect(all['advanced']!.opensPage, isTrue);
    });

    test('extra actions come first', () {
      const extra = ContextModalAction(id: 'x', icon: AppIcons.add, label: 'X');
      final sections = songModalSections(
        _l10n,
        _data(links: _links()),
        _handlers,
        extra: const [extra],
      );
      expect(sections.first.single.id, 'x');
    });
  });

  group('Advanced page', () {
    List<String> ids(bool canFindLyrics) => [
      for (final s in songModalAdvancedSections(
        _l10n,
        _data(canFindLyrics: canFindLyrics),
        _handlers,
      ))
        for (final a in s) a.id,
    ];

    test('offers Find lyrics online when the song can be searched', () {
      expect(ids(true), contains('find-lyrics'));
    });

    test('leaves it out otherwise', () {
      expect(ids(false), isNot(contains('find-lyrics')));
    });

    test('keeps the actions not available yet', () {
      expect(ids(false), ['remove-from-library', 'delete-file']);
    });

    test('Delete file is destructive; Remove from library keeps the files', () {
      final rows = {
        for (final s in songModalAdvancedSections(
          _l10n,
          _data(canFindLyrics: false),
          _handlers,
        ))
          for (final a in s) a.id: a,
      };
      expect(rows['delete-file']!.destructive, isTrue);
      expect(rows['remove-from-library']!.destructive, isFalse);
      expect(rows['remove-from-library']!.subtitle, 'Keeps the files');
    });
  });

  test('folder name is the last part of the directory', () {
    expect(songFolderName('/music/Rock/a.flac'), 'Rock');
    expect(songFolderName('/a.flac'), '');
  });
}
