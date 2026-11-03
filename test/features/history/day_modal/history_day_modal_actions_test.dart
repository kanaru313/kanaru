import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kanaru/core/database/history_rows.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/features/history/day_modal/history_day_modal_actions.dart';
import 'package:kanaru/features/history/day_modal/history_day_modal_data.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_spec.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

/// Noon on Friday 2026-10-23.
final _now = DateTime(2026, 10, 23, 12);

TrackListItem _track(String name) =>
    TrackListItem(id: 1, path: '/m/$name.flac', title: name);

HistoryPlayRow _play(
  int id,
  String name, {
  int? listenedMs = 60000,
  bool gone = false,
}) => HistoryPlayRow(
  id: id,
  path: '/m/$name.flac',
  playedAt: 0,
  listenedMs: listenedMs,
  track: gone ? null : _track(name),
);

HistoryDayModalData _data(List<HistoryPlayRow> rows, {DateTime? day}) =>
    HistoryDayModalData(
      day: day ?? DateTime(2026, 10, 23),
      rows: rows,
      covers: null,
    );

HistoryDayModalHandlers _handlers() {
  void noop() {}
  return HistoryDayModalHandlers(
    playAll: noop,
    shuffle: noop,
    addToPlaylist: noop,
    openInMostPlayed: noop,
    exportAbsolute: noop,
    exportRelative: noop,
    remove: (_) {},
  );
}

Map<String, ContextModalAction> _rows(HistoryDayModalData data) => {
  for (final g in historyDayModalSections(_l10n, data, _handlers()))
    for (final a in g) a.id: a,
};

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  // Newest first, as the page lists them: gone, A, B, A.
  final rows = [
    _play(4, 'gone', gone: true),
    _play(3, 'A'),
    _play(2, 'B'),
    _play(1, 'A'),
  ];

  group('data', () {
    test('counts library songs once each and every play', () {
      final data = _data(rows);
      expect(data.plays, 4);
      expect(data.songs, 2);
      expect([for (final t in data.tracks) t.uri], ['/m/A.flac', '/m/B.flac']);
      expect(data.playIds, [4, 3, 2, 1]);
      expect(data.canQueue, isTrue);
      expect(data.canRemove, isTrue);
      expect(
        [for (final e in data.exportEntries) e.path],
        ['/m/A.flac', '/m/B.flac'],
      );
    });

    test('listened time adds the known plays and is left out when unknown', () {
      expect(
        _data(rows).statsLine(_l10n),
        '4 listens • 3 songs • listened 4 min',
      );
      final unknown = _data([_play(1, 'A', listenedMs: null)]);
      expect(unknown.listenedMs, isNull);
      expect(unknown.statsLine(_l10n), '1 listen • 1 song');
      final partly = _data([_play(1, 'A'), _play(2, 'B', listenedMs: null)]);
      expect(partly.listenedMs, 60000);
    });

    test('the title is Today, Yesterday or the weekday', () {
      String title(DateTime day) => _data(rows, day: day).title(_l10n, _now);
      expect(title(DateTime(2026, 10, 23)), 'Today');
      expect(title(DateTime(2026, 10, 22)), 'Yesterday');
      expect(title(DateTime(2026, 10, 20)), 'Tuesday');
      expect(title(DateTime(2026, 10, 24)), 'Saturday');
    });
  });

  group('first page', () {
    test('three groups: play, copy and export, then Remove', () {
      final groups = historyDayModalSections(_l10n, _data(rows), _handlers());
      expect(
        [
          for (final g in groups) [for (final a in g) a.id],
        ],
        [
          ['play-all', 'shuffle'],
          ['add-to-playlist', 'open-in-most-played', 'export-m3u'],
          ['remove-day'],
        ],
      );
      final all = _rows(_data(rows));
      expect(all.values.every((a) => a.enabled), isTrue);
      expect(all['remove-day']!.destructive, isTrue);
      expect(all.containsKey('advanced'), isFalse);
    });

    test('subtitles count the library songs the actions use', () {
      final all = _rows(_data(rows));
      expect(all['play-all']!.subtitle, '2 songs, last played first');
      expect(
        all['add-to-playlist']!.subtitle,
        'New playlist suggests “Oct 23, 2026”',
      );
      expect(
        all['remove-day']!.subtitle,
        '4 listens · songs stay in your library',
      );
    });

    test('a day of songs gone from the library only allows Remove', () {
      final all = _rows(_data([_play(1, 'x', gone: true)]));
      for (final id in ['play-all', 'shuffle', 'add-to-playlist']) {
        expect(all[id]!.enabled, isFalse, reason: id);
      }
      expect(all['remove-day']!.enabled, isTrue);
    });

    test('a day with no play allows nothing to act on', () {
      final all = _rows(_data(const []));
      expect(all['remove-day']!.enabled, isFalse);
      expect(all['play-all']!.enabled, isFalse);
    });
  });

  group('Open in Most played and export', () {
    test('subtitles say the date and the order', () {
      final all = _rows(_data(rows));
      expect(all['open-in-most-played']!.subtitle, 'Oct 23, 2026');
      expect(all['export-m3u']!.subtitle, contains('Absolute paths'));
      expect(
        all['export-m3u']!.subtitle,
        contains('2 songs, last played first'),
      );
    });

    test('exports need a library song; Open in Most played does not', () {
      final all = _rows(_data([_play(1, 'x', gone: true)]));
      expect(all['export-m3u']!.enabled, isFalse);
      expect(all['export-m3u']!.trailing, isEmpty);
      expect(all['open-in-most-played']!.enabled, isTrue);
    });
  });
}
