import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_album_links.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/shared/genre_modal/genre_modal_actions.dart';
import 'package:kanaru/shared/genre_modal/genre_modal_data.dart';
import 'package:kanaru/shared/genre_modal/genre_modal_links.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_spec.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';

import '../../features/library/browse_test_data.dart';
import '../../features/library/library_test_harness.dart';
import '../../features/search/search_test_data.dart';
import 'genre_modal_test_support.dart';

final _l10n = AppLocalizationsEn();

GenreModalHandlers get _handlers => GenreModalHandlers(
  goToGenre: () {},
  goToAlbum: (_) {},
  goToFolder: (_) {},
  showInFileManager: (_) {},
  playAll: () {},
  shuffle: () {},
  addToPlaylist: () {},
  addAllToFavorites: () {},
);

List<ContextModalAction> _rows({
  GenreLinks? links,
  bool showGenre = true,
}) => [
  for (final s in genreModalSections(
    _l10n,
    GenreModalData(genre: testGenre, links: links, showGenre: showGenre),
    _handlers,
  ))
    ...s,
];

Map<String, ContextModalAction> _byId(GenreLinks? links) => {
  for (final a in _rows(links: links)) a.id: a,
};

List<String> _ids(GenreLinks? links, {bool showGenre = true}) => [
  for (final a in _rows(links: links, showGenre: showGenre)) a.id,
];

AlbumFolder _folder(String path, int n) =>
    AlbumFolder(path: path, songCount: n, samplePath: '$path/1.flac');

void main() {
  group('sections unit tests', () {
    test('rows in order, links then actions', () {
      expect(_ids(linksOf()), [
        'genre',
        'album',
        'folder',
        'play-all',
        'shuffle',
        'add-to-playlist',
        'edit-tags',
        'advanced',
      ]);
    });

    test('Go to genre is left out on the genre page; otherwise named', () {
      expect(_ids(linksOf(), showGenre: false), isNot(contains('genre')));
      expect(_byId(linksOf())['genre']!.subtitle, 'Rock');
    });

    group('albums', () {
      test('loading: greyed row, no subtitle', () {
        final a = _byId(null)['album']!;
        expect(a.enabled, isFalse);
        expect(a.subtitle, isNull);
      });

      test('none: greyed, no album', () {
        final a = _byId(linksOf(albums: []))['album']!;
        expect(a.enabled, isFalse);
        expect(a.subtitle, 'No album');
      });

      test('one album: plain row with its title', () {
        final a = _byId(linksOf())['album']!;
        expect(a.subtitle, 'Album 0');
        expect(a.chips, isNull);
        expect(a.opensPage, isFalse);
        expect(a.onTap, isNotNull);
      });

      for (final n in [2, 3]) {
        test('$n albums: wrapped chips, open', () {
          final a = _byId(linksOf(albums: testAlbums(n)))['albums']!;
          expect(a.subtitle, '$n albums');
          expect(a.chips!.wrap, isTrue);
          expect(a.chips!.initiallyExpanded, isTrue);
          expect(a.opensPage, isFalse);
          expect(
            [for (final c in a.chips!.items) c.label],
            [for (var i = 0; i < n; i++) 'Album $i'],
          );
        });
      }

      for (final n in [4, 12]) {
        test('$n albums: opens a page', () {
          final a = _byId(linksOf(albums: testAlbums(n)))['albums']!;
          expect(a.subtitle, '$n albums');
          expect(a.opensPage, isTrue);
          expect(a.chips, isNull);
        });
      }
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
            folders: [
              _folder('/m/a', 5),
              _folder('/m/b', 2),
              _folder('/m/c', 1),
            ],
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
  });

  group('modal widget actions', () {
    testWidgets('Play all and Shuffle play the genre tracks', (tester) async {
      final h = LibraryHarness();
      final tracks = [
        const TestTrack('Alpha', genre: 'Rock', album: 'Alb', track: 1),
        const TestTrack('Zulu', genre: 'Rock', album: 'Alb', track: 2),
      ];
      await openWithTracks(tester, h, tracks, location: '/genres');
      await pumpGenreHost(tester, container: h.container);
      await tester.pumpAndSettle();

      await openGenreModalOf(tester);
      await tapGenreRow(tester, 'Play all');
      await settleIo(tester, h);
      expect(queuedTitles(h), ['Alpha', 'Zulu']);

      await openGenreModalOf(tester);
      await tapGenreRow(tester, 'Shuffle');
      await settleIo(tester, h);
      expect(h.container.read(playerServiceProvider).queue.tracks, hasLength(2));
    });

    testWidgets('Add to playlist and footer run queue actions', (tester) async {
      final host = await pumpGenreHost(tester, links: linksOf());
      await openGenreModalOf(tester);

      await tapGenreRow(tester, 'Add to playlist…');
      expect(host.queueActions, [QueueAction.addToPlaylist]);

      await openGenreModalOf(tester);
      await tapGenreRow(tester, 'Play next');
      expect(host.queueActions, [
        QueueAction.addToPlaylist,
        QueueAction.playNext,
      ]);

      await openGenreModalOf(tester);
      await tapGenreRow(tester, 'Add to queue');
      expect(host.queueActions, [
        QueueAction.addToPlaylist,
        QueueAction.playNext,
        QueueAction.addToQueue,
      ]);
    });

    testWidgets('Advanced page displays options and handles file manager & coming soon', (
      tester,
    ) async {
      final host = await pumpGenreHost(tester, links: linksOf());
      await openGenreModalOf(tester);

      await tapGenreRow(tester, 'Edit tags');
      expect(find.textContaining("isn't available yet"), findsOneWidget);

      await tapGenreRow(tester, 'Advanced');
      expect(find.text('Advanced'), findsOneWidget);
      expect(find.text('Add all to Favorites'), findsOneWidget);
      expect(find.text('Show in file manager'), findsOneWidget);
      expect(find.text('/m/Rock'), findsOneWidget);
      expect(find.text('Split or merge genre'), findsOneWidget);
      expect(find.text('Remove from library'), findsOneWidget);
      expect(find.text('Delete files'), findsOneWidget);

      await tapGenreRow(tester, 'Split or merge genre');
      expect(find.textContaining("isn't available yet"), findsOneWidget);

      await tapGenreRow(tester, 'Remove from library');
      expect(find.textContaining("isn't available yet"), findsOneWidget);

      await tapGenreRow(tester, 'Delete files');
      expect(find.textContaining("isn't available yet"), findsOneWidget);

      await tapGenreRow(tester, 'Show in file manager');
      expect(host.shownInFileManager, ['/m/Rock/1.flac']);
    });

    testWidgets('Add all to Favorites adds genre tracks to Favorites playlist', (
      tester,
    ) async {
      final h = LibraryHarness();
      final tracks = [
        const TestTrack('RockSong', genre: 'Rock', path: '/m/Rock/1.flac'),
      ];
      await openWithTracks(tester, h, tracks, location: '/genres');
      await pumpGenreHost(tester, container: h.container);
      await tester.pumpAndSettle();

      await openGenreModalOf(tester);
      await tapGenreRow(tester, 'Advanced');
      await tester.tap(genreModalAction('add-all-to-favorites'));
      await settleIo(tester, h);
      await tester.pumpAndSettle();

      final favId = await tester.runAsync(() => h.db.favoritesPlaylistId());
      expect(favId, isNotNull);
      final entries = await tester.runAsync(
        () => (h.db.select(h.db.playlistEntries)
              ..where((e) => e.playlistId.equals(favId!))
              ..orderBy([(e) => OrderingTerm.asc(e.position)]))
            .get(),
      );
      expect(entries!.map((e) => e.path), ['/m/Rock/1.flac']);
      expect(find.text('Added to Favorites: Rock'), findsOneWidget);
    });
  });
}
