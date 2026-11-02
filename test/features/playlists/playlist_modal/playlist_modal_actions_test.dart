import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show InkWell;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_modal_queries.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/features/playlists/playlist_modal/playlist_modal_actions.dart';
import 'package:kanaru/features/playlists/playlist_modal/playlist_modal_data.dart';
import 'package:kanaru/features/playlists/playlist_page_data.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_spec.dart';

import '../../library/browse_test_data.dart';
import '../../library/library_test_harness.dart';
import '../playlist_test_data.dart';
import 'playlist_modal_test_support.dart';

PlaylistSummary _playlist({
  int count = 3,
  bool favorites = false,
  String description = '',
}) => PlaylistSummary(
  id: 7,
  name: 'Mix',
  createdAt: 1,
  entryCount: count,
  isFavorites: favorites,
  description: description,
);

/// The data of a playlist as the page would build it: [loaded] false is the
/// state before the head arrived, [gone] a head that says the playlist is
/// not there.
PlaylistModalData _data({
  PlaylistSummary? playlist,
  bool hasPlayable = true,
  bool loaded = true,
  bool gone = false,
  PlaylistModalStats? stats,
  bool showGoTo = true,
}) {
  final p = playlist ?? _playlist();
  return PlaylistModalData(
    snapshot: p,
    snapshotCoverKeys: const [],
    load: !loaded
        ? null
        : PlaylistHeadLoad(
            seq: 1,
            head: gone
                ? null
                : PlaylistPageHead(
                    playlist: p,
                    coverKeys: const [],
                    hasPlayable: hasPlayable,
                  ),
          ),
    stats: stats,
    showGoTo: showGoTo,
  );
}

PlaylistModalHandlers _handlers() {
  void noop() {}
  return PlaylistModalHandlers(
    goToPlaylist: noop,
    play: noop,
    shuffle: noop,
    addToPlaylist: noop,
    edit: noop,
    delete: (_) {},
    addAllToFavorites: noop,
    duplicate: noop,
    exportAbsolute: noop,
    exportRelative: noop,
    removeDuplicates: noop,
    removeMissing: noop,
    openAdvanced: (_) {},
  );
}

final _l10n = lookupAppLocalizations(const Locale('en'));

Map<String, ContextModalAction> _rows(PlaylistModalData data) => {
  for (final group in playlistModalSections(_l10n, data, _handlers()))
    for (final a in group) a.id: a,
};

Map<String, ContextModalAction> _advanced(PlaylistModalData data) => {
  for (final group in playlistModalAdvancedSections(_l10n, data, _handlers()))
    for (final a in group) a.id: a,
};

void main() {
  group('actions page rows', () {
    test('an ordinary playlist has every row, Delete right after Edit', () {
      final groups = playlistModalSections(_l10n, _data(), _handlers());
      expect(
        [
          for (final g in groups) [for (final a in g) a.id],
        ],
        [
          ['go-to-playlist'],
          ['play-all', 'shuffle', 'add-to-playlist', 'advanced'],
          ['edit', 'delete'],
        ],
      );
      final rows = _rows(_data());
      expect(rows.values.every((a) => a.enabled), isTrue);
      expect(rows['delete']!.destructive, isTrue);
      expect(rows['go-to-playlist']!.subtitle, 'Mix');
      expect(
        rows['add-to-playlist']!.subtitle,
        'Copy 3 songs to another playlist',
      );
      expect(rows['advanced']!.opensPage, isTrue);
    });

    test('Favorites has no Edit and no Delete', () {
      final rows = _rows(_data(playlist: _playlist(favorites: true)));
      expect(rows.keys, isNot(contains('edit')));
      expect(rows.keys, isNot(contains('delete')));
      expect(rows.keys, contains('play-all'));
    });

    test('an empty playlist cannot play, copy or queue', () {
      final rows = _rows(
        _data(playlist: _playlist(count: 0), hasPlayable: false),
      );
      for (final id in ['play-all', 'shuffle', 'add-to-playlist']) {
        expect(rows[id]!.enabled, isFalse, reason: id);
      }
      expect(rows['edit']!.enabled, isTrue);
      final advanced = _advanced(
        _data(playlist: _playlist(count: 0), hasPlayable: false),
      );
      expect(advanced['export-absolute']!.enabled, isFalse);
      expect(advanced['export-relative']!.enabled, isFalse);
      expect(advanced['add-all-to-favorites']!.enabled, isFalse);
    });

    test('a playlist of missing songs only cannot play but can be copied', () {
      final data = _data(hasPlayable: false);
      final rows = _rows(data);
      expect(rows['play-all']!.enabled, isFalse);
      expect(rows['shuffle']!.enabled, isFalse);
      expect(rows['add-to-playlist']!.enabled, isTrue);
      expect(_advanced(data)['export-absolute']!.enabled, isTrue);
    });

    test('showGoTo false leaves Go to playlist out', () {
      expect(
        _rows(_data(showGoTo: false)).keys,
        isNot(contains('go-to-playlist')),
      );
    });

    test(
      'before the head arrives play, shuffle and Add all are greyed out',
      () {
        final data = _data(loaded: false);
        final rows = _rows(data);
        expect(rows['play-all']!.enabled, isFalse);
        expect(rows['shuffle']!.enabled, isFalse);
        expect(_advanced(data)['add-all-to-favorites']!.enabled, isFalse);
        // The snapshot's text is shown meanwhile.
        expect(rows['go-to-playlist']!.subtitle, 'Mix');
      },
    );

    test('a playlist deleted elsewhere greys out every acting row', () {
      final data = _data(gone: true);
      for (final a in [..._rows(data).values, ..._advanced(data).values]) {
        if (a.id == 'advanced') continue;
        expect(a.enabled, isFalse, reason: a.id);
      }
    });
  });

  group('advanced page rows', () {
    test('clean-ups show only for counts above zero', () {
      expect(_advanced(_data()).keys, isNot(contains('remove-duplicates')));
      expect(_advanced(_data()).keys, isNot(contains('remove-missing')));
      final both = _advanced(
        _data(stats: const PlaylistModalStats(missing: 2, repeats: 3)),
      );
      expect(
        both['remove-duplicates']!.subtitle,
        '3 repeated songs · keeps the first one',
      );
      expect(both['remove-missing']!.subtitle, '2 songs not in your library');
      final none = _advanced(
        _data(stats: const PlaylistModalStats(missing: 0, repeats: 0)),
      );
      expect(none.keys, isNot(contains('remove-duplicates')));
      expect(none.keys, isNot(contains('remove-missing')));
    });

    test(
      'Favorites keeps Remove missing but not Remove duplicates or Add all',
      () {
        final rows = _advanced(
          _data(
            playlist: _playlist(favorites: true),
            stats: const PlaylistModalStats(missing: 1, repeats: 2),
          ),
        );
        expect(rows.keys, isNot(contains('remove-duplicates')));
        expect(rows.keys, isNot(contains('add-all-to-favorites')));
        expect(rows.keys, contains('remove-missing'));
      },
    );

    test('Duplicate names the copy and the exports say which paths', () {
      final rows = _advanced(_data());
      expect(rows['duplicate']!.subtitle, 'Mix (copy)');
      expect(rows['export-absolute']!.subtitle, 'Absolute paths');
      expect(
        rows['export-relative']!.subtitle,
        'Relative paths (next to the music)',
      );
    });
  });

  group('wired to a playlist', () {
    late LibraryHarness h;
    setUp(() => h = LibraryHarness());

    testWidgets('right click shows the rows and enabled queue buttons', (
      tester,
    ) async {
      await insertTracks(tester, h, const [TestTrack('a'), TestTrack('b')]);
      final id = await seedPlaylist(tester, h, 'Mix', ['a', 'b']);
      await pumpModalHost(tester, h, id: id);
      await openPlaylistModalOf(tester);

      expect(find.text('Mix'), findsWidgets);
      expect(modalAction('play-all'), findsOneWidget);
      expect(modalAction('edit'), findsOneWidget);
      // Delete is directly below Edit.
      final edit = tester.getTopLeft(modalAction('edit')).dy;
      final delete = tester.getTopLeft(modalAction('delete')).dy;
      expect(delete, greaterThan(edit));
      expect(delete - edit, lessThan(80));
      final next = find.byKey(const ValueKey('playlist-modal-play-next'));
      expect(tester.widget<InkWell>(next).onTap, isNotNull);
    });

    testWidgets('an empty playlist disables play and the queue buttons', (
      tester,
    ) async {
      await insertTracks(tester, h, const [TestTrack('a')]);
      final id = await seedPlaylist(tester, h, 'Empty', []);
      await pumpModalHost(tester, h, id: id);
      await openPlaylistModalOf(tester);

      final next = find.byKey(const ValueKey('playlist-modal-play-next'));
      expect(tester.widget<InkWell>(next).onTap, isNull);
      await tester.tap(modalAction('play-all'));
      await settleModal(tester);
      expect(modalAction('play-all'), findsOneWidget, reason: 'still open');
    });
  });
}
