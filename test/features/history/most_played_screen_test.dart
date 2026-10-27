import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/history/history_screen_states.dart';
import 'package:kanaru/features/history/history_clock.dart';
import 'package:kanaru/features/history/history_routes.dart';
import 'package:kanaru/features/history/history_top_view.dart';
import 'package:kanaru/features/history/most_played_screen.dart';

import 'history_test_harness.dart';

void main() {
  late LibraryHarness h;

  setUp(() => h = historyHarness());

  historyTestWidgets('shows the ranking under the Most played title', (
    tester,
  ) async {
    await openHistory(
      tester,
      h,
      tracks: [song('A')],
      plays: [('A', DateTime(2026, 10, 22, 9))],
      page: mostPlayedPath,
    );

    expect(find.byType(MostPlayedScreen), findsOneWidget);
    expect(find.byType(HistoryTopView), findsOneWidget);
    expect(find.text('Most played'), findsWidgets);
    expect(find.text('Play all'), findsOneWidget);
    expect(location(h), mostPlayedPath);
  });

  historyTestWidgets('the History page has no tabs', (tester) async {
    await openHistory(
      tester,
      h,
      tracks: [song('A')],
      plays: [('A', DateTime(2026, 10, 22, 9))],
    );

    expect(find.byType(HistoryTopView), findsNothing);
    expect(find.text('Journal'), findsNothing);
    expect(find.byTooltip('Jump to a day'), findsOneWidget);
  });

  historyTestWidgets('without a library shows the unavailable state', (
    tester,
  ) async {
    h = LibraryHarness(
      hasDatabase: false,
      overrides: [historyNowProvider.overrideWithValue(() => historyTestNow)],
    );
    await h.pump(tester);
    goTo(tester, h, mostPlayedPath);
    await settleHistory(tester);

    expect(find.byType(MostPlayedScreen), findsOneWidget);
    expect(find.byType(HistoryUnavailable), findsOneWidget);
    expect(find.byType(HistoryTopView), findsNothing);
    expect(find.text('Most played'), findsWidgets);
  });
}
