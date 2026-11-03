import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/history_rows.dart';
import 'package:kanaru/features/history/history_modal/history_page_modal_actions.dart';
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
    addToPlaylist: noop,
    openMostPlayed: noop,
    exportAbsolute: noop,
    exportRelative: noop,
    openAdvanced: (_) {},
  );
}

Map<String, ContextModalAction> _byId(List<List<ContextModalAction>> groups) =>
    {
      for (final g in groups)
        for (final a in g) a.id: a,
    };

void main() {
  test('the first page lists add to playlist, most played, advanced', () {
    final groups = historyPageModalSections(_l10n, _overview(3), _handlers());
    expect(groups, hasLength(1));
    final rows = _byId(groups);
    expect(rows.keys, ['add-to-playlist', 'most-played', 'advanced']);
    expect(
      rows['add-to-playlist']!.subtitle,
      'New playlist suggests “History”',
    );
    expect(rows['most-played']!.subtitle, 'Songs you play the most');
    expect(rows['advanced']!.opensPage, isTrue);
    expect(rows['advanced']!.onTap, isNotNull);
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
      expect(rows['most-played']!.enabled, isTrue);
      final adv = _byId(
        historyPageModalAdvancedSections(_l10n, overview, _handlers()),
      );
      expect(adv['export-absolute']!.enabled, enabled);
      expect(adv['export-relative']!.enabled, enabled);
    }
  });

  test(
    'the advanced page exports absolute and relative, last played first',
    () {
      final adv = _byId(
        historyPageModalAdvancedSections(_l10n, _overview(2), _handlers()),
      );
      expect(adv.keys, ['export-absolute', 'export-relative', 'clear']);
      expect(adv['export-absolute']!.subtitle, contains('Absolute'));
      expect(adv['export-relative']!.subtitle, contains('Relative'));
      for (final a in [adv['export-absolute']!, adv['export-relative']!]) {
        expect(a.label, 'Export as M3U');
        expect(a.subtitle, contains('Last played first'));
      }
    },
  );

  group('Clear history', () {
    HistoryPageModalHandlers withClear() => HistoryPageModalHandlers(
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
      historyPageModalAdvancedSections(_l10n, overview, h, clearing: clearing),
    )['clear']!;

    test('is its own destructive group with a hint', () {
      final groups = historyPageModalAdvancedSections(
        _l10n,
        _overview(2),
        withClear(),
      );
      expect(groups, hasLength(2));
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
