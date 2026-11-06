import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_source_pref_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_search_controller.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/lookup_test_harness.dart';
import 'disabled_sources_harness.dart';

void main() {
  late NamedSource alpha;
  late NamedSource beta;
  late NamedSource gamma;

  setUp(() {
    alpha = NamedSource('alpha', 'Alpha', 'alpha.example.com', title: 'Song a');
    beta = NamedSource('beta', 'Beta', 'beta.example.com', title: 'Song b');
    gamma = NamedSource('gamma', 'Gamma', 'gamma.example.com');
  });

  Future<LyricsHarness> openModal(WidgetTester tester) async {
    final h = await openPickerWith(tester, on: [alpha], off: [beta, gamma]);
    await tester.tap(find.byType(OutlinedButton));
    await settleUi(tester);
    return h;
  }

  testWidgets('lists All sources, the on sources and an Off group', (
    tester,
  ) async {
    await openModal(tester);

    expect(find.text('Search sources'), findsOneWidget);
    expect(sourceRow('All sources'), findsOneWidget);
    expect(sourceRow('Alpha'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(sourceRow('Beta'), findsOneWidget);
    expect(find.text('beta.example.com'), findsOneWidget);
    // The count of the on source and of All sources.
    expect(
      find.descendant(of: sourceRow('Alpha'), matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('beta.example.com'),
          matching: find.byType(SelectionRow),
        ),
        matching: find.text('Search'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Search on an off row asks that source only, settings stay', (
    tester,
  ) async {
    final h = await openModal(tester);

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('beta.example.com'),
          matching: find.byType(SelectionRow),
        ),
        matching: find.text('Search'),
      ),
    );
    await settleUi(tester);

    expect(beta.searchCalls, 1);
    expect(gamma.searchCalls, 0);
    expect(find.text('Source is off'), findsWidgets);
    expect(
      await tester.runAsync(() => h.db.watchLyricsSourcePrefs().first),
      isEmpty,
    );
    expect(
      h.container.read(lyricsSearchControllerProvider(fakeTarget)).onDemand,
      {'beta'},
    );
  });

  testWidgets('tapping the off row itself searches that source', (
    tester,
  ) async {
    await openModal(tester);
    await tester.tap(find.text('beta.example.com'));
    await settleUi(tester);
    expect(beta.searchCalls, 1);
    expect(beta.searchedTexts, ['Artist Song']);
  });

  testWidgets('a searched off source filters the list and closes the modal', (
    tester,
  ) async {
    await openModal(tester);
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('beta.example.com'),
          matching: find.byType(SelectionRow),
        ),
        matching: find.text('Search'),
      ),
    );
    await settleUi(tester);

    await tester.tap(sourceRow('Beta'));
    await settleUi(tester);

    expect(find.text('Search sources'), findsNothing);
    expect(find.text('Song a'), findsNothing);
    expect(find.text('Song b'), findsOneWidget);
  });
}
