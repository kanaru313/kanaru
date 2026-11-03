import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kanaru/core/database/playlist_modal_queries.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/features/playlists/playlist_page_data.dart';
import 'package:kanaru/features/playlists/saved_queue_modal/saved_queue_modal_actions.dart';
import 'package:kanaru/features/playlists/saved_queue_modal/saved_queue_modal_data.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_spec.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

/// The data of a saved queue as the page would build it: [loaded] false is
/// the state before the head arrived, [gone] a head that says the queue is
/// not there.
SavedQueueModalData _data({
  bool hasPlayable = true,
  bool loaded = true,
  bool gone = false,
  PlaylistModalStats? stats,
  bool showGoTo = true,
}) {
  final queue = PlaylistSummary(
    id: 7,
    name: 'placeholder',
    createdAt: DateTime(2026, 10, 22, 21, 30).millisecondsSinceEpoch,
    entryCount: 3,
  );
  return SavedQueueModalData(
    snapshot: queue,
    snapshotCoverKeys: const [],
    l10n: _l10n,
    load: !loaded
        ? null
        : PlaylistHeadLoad(
            seq: 1,
            head: gone
                ? null
                : PlaylistPageHead(
                    playlist: queue,
                    coverKeys: const [],
                    hasPlayable: hasPlayable,
                  ),
          ),
    stats: stats,
    showGoTo: showGoTo,
  );
}

SavedQueueModalHandlers _handlers() {
  void noop() {}
  return SavedQueueModalHandlers(
    goToQueue: noop,
    play: noop,
    shuffle: noop,
    addToPlaylist: noop,
    delete: (_) {},
    addAllToFavorites: noop,
    exportAbsolute: noop,
    exportRelative: noop,
    removeMissing: (_) {},
    openAdvanced: (_) {},
  );
}

Map<String, ContextModalAction> _rows(SavedQueueModalData data) => {
  for (final group in savedQueueModalSections(_l10n, data, _handlers()))
    for (final a in group) a.id: a,
};

Map<String, ContextModalAction> _advanced(SavedQueueModalData data) => {
  for (final group in savedQueueModalAdvancedSections(_l10n, data, _handlers()))
    for (final a in group) a.id: a,
};

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  group('saved queue rows', () {
    test('first page has no Edit; Delete and Go to are named for a queue', () {
      final rows = _rows(_data());
      expect(rows.keys, isNot(contains('edit')));
      expect(rows['go-to-playlist']!.label, 'Go to queue');
      expect(rows['delete']!.label, 'Delete queue');
      expect(rows['delete']!.destructive, isTrue);
      expect(rows['add-to-playlist']!.enabled, isTrue);
    });

    test('the page of the queue itself has no Go to queue', () {
      expect(
        _rows(_data(showGoTo: false)).keys,
        isNot(contains('go-to-playlist')),
      );
    });

    test('Add to playlist is greyed when nothing can play', () {
      final rows = _rows(_data(hasPlayable: false));
      expect(rows['add-to-playlist']!.enabled, isFalse);
      expect(rows['play-all']!.subtitle, _l10n.queueHistoryNothingToPlay);
      expect(rows['delete']!.enabled, isTrue);
    });

    test('while the head loads the acting rows are greyed, silently', () {
      final rows = _rows(_data(loaded: false, hasPlayable: false));
      expect(rows['play-all']!.enabled, isFalse);
      expect(rows['play-all']!.subtitle, isNull);
    });

    test('a queue that is gone greys everything but Advanced', () {
      final data = _data(gone: true, hasPlayable: false);
      for (final a in [..._rows(data).values, ..._advanced(data).values]) {
        if (a.id == 'advanced') continue;
        expect(a.enabled, isFalse, reason: a.id);
      }
    });

    test('Advanced has no Duplicate and no Remove duplicates', () {
      final rows = _advanced(
        _data(stats: const PlaylistModalStats(missing: 2, repeats: 3)),
      );
      expect(rows.keys, isNot(contains('duplicate')));
      expect(rows.keys, isNot(contains('remove-duplicates')));
      expect(rows.keys, contains('remove-missing'));
      expect(rows.keys, contains('add-all-to-favorites'));
    });

    test('Remove missing songs shows only when something is missing', () {
      expect(_advanced(_data()).keys, isNot(contains('remove-missing')));
    });
  });
}
