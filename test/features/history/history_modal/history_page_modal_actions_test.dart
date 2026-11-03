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
      expect(adv.keys, ['export-absolute', 'export-relative']);
      expect(adv['export-absolute']!.subtitle, contains('Absolute'));
      expect(adv['export-relative']!.subtitle, contains('Relative'));
      for (final a in adv.values) {
        expect(a.label, 'Export as M3U');
        expect(a.subtitle, contains('Last played first'));
      }
    },
  );
}
