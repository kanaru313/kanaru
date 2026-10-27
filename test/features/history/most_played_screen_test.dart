import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/history/history_screen_states.dart';
import 'package:kanaru/features/history/history_clock.dart';
import 'package:kanaru/features/history/history_routes.dart';
import 'package:kanaru/features/history/most_played_view.dart';
import 'package:kanaru/features/history/most_played_screen.dart';
import 'package:material_ui/material_ui.dart';

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
    expect(find.byType(MostPlayedView), findsOneWidget);
    expect(find.text('Most played'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
    expect(location(h), mostPlayedPath);
  });

  historyTestWidgets('the History page has no tabs', (tester) async {
    await openHistory(
      tester,
      h,
      tracks: [song('A')],
      plays: [('A', DateTime(2026, 10, 22, 9))],
    );

    expect(find.byType(MostPlayedView), findsNothing);
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
    expect(find.byType(MostPlayedView), findsNothing);
    expect(find.text('Most played'), findsWidgets);
  });
}
