import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/history_rows.dart';
import 'package:kanaru/features/history/history_page_modal/history_page_modal_actions.dart';
import 'package:kanaru/features/history/history_page_modal/history_page_modal_data.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_spec.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

HistoryOverview _overview(int plays) => HistoryOverview(
  plays: plays,
  tracks: plays,
  firstPlayedAt: null,
  coverKeys: const [],
);

HistoryPageModalHandlers _handlers() {
  void noop() {}
  return HistoryPageModalHandlers(
    play: noop,
    shuffle: noop,
    addToPlaylist: noop,
    openMostPlayed: noop,
    exportAbsolute: noop,
    exportRelative: noop,
  );
}

Map<String, ContextModalAction> _byId(List<List<ContextModalAction>> groups) =>
    {
      for (final g in groups)
        for (final a in g) a.id: a,
    };

void main() {
  test('the page lists play all and shuffle; add to playlist, most played, export; clear', () {
    final groups = historyPageModalSections(_l10n, _overview(3), _handlers());
    expect(
      [
        for (final g in groups) [for (final a in g) a.id],
      ],
      [
        ['play-all', 'shuffle'],
        ['add-to-playlist', 'most-played', 'export-m3u'],
        ['clear'],
      ],
    );
    final rows = _byId(groups);
    expect(
      rows['add-to-playlist']!.subtitle,
      'New playlist suggests “History”',
    );
    expect(rows['most-played']!.subtitle, 'Songs you play the most');
    expect(rows.containsKey('advanced'), isFalse);
  });

  test('song rows follow the listen count; Most played is always on', () {
    for (final (overview, enabled) in [
      (_overview(3), true),
      (_overview(0), false),
      (null, false),
    ]) {
      final rows = _byId(
        historyPageModalSections(_l10n, overview, _handlers()),
      );
      expect(rows['add-to-playlist']!.enabled, enabled);
      expect(rows['play-all']!.enabled, enabled);
      expect(rows['shuffle']!.enabled, enabled);
      expect(rows['most-played']!.enabled, isTrue);
      expect(rows['export-m3u']!.enabled, enabled);
      expect(rows['export-m3u']!.trailing, enabled ? hasLength(1) : isEmpty);
    }
  });

  test('the export row writes absolute paths, last played first', () {
    final rows = _byId(
      historyPageModalSections(_l10n, _overview(2), _handlers()),
    );
    final a = rows['export-m3u']!;
    expect(a.label, 'Export as M3U');
    expect(a.subtitle, contains('Absolute'));
    expect(a.subtitle, contains('Last played first'));
    expect(a.trailing.single.tooltip, 'Export with relative paths');
  });

  group('Clear history', () {
    HistoryPageModalHandlers withClear() => HistoryPageModalHandlers(
      play: () {},
      shuffle: () {},
      addToPlaylist: () {},
      openMostPlayed: () {},
      exportAbsolute: () {},
      exportRelative: () {},
      clear: (_) {},
    );

    ContextModalAction clear(
      HistoryOverview? overview,
      HistoryPageModalHandlers h, {
      bool clearing = false,
    }) => _byId(
      historyPageModalSections(_l10n, overview, h, clearing: clearing),
    )['clear']!;

    test('is its own destructive group with a hint', () {
      final groups = historyPageModalSections(_l10n, _overview(2), withClear());
      expect(groups, hasLength(3));
      final row = groups.last.single;
      expect(row.label, 'Clear history…');
      expect(row.subtitle, 'Last hour, today, 7 days or everything');
      expect(row.destructive, isTrue);
    });

    test('needs a recorder, a listen and no clear running', () {
      expect(clear(_overview(2), withClear()).enabled, isTrue);
      expect(clear(_overview(0), withClear()).enabled, isFalse);
      expect(clear(null, withClear()).enabled, isFalse);
      expect(clear(_overview(2), withClear(), clearing: true).enabled, isFalse);
      expect(clear(_overview(2), _handlers()).enabled, isFalse);
    });
  });
}
