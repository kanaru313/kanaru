import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_search_controller.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_disabled_sources_card.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_dialog.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_failure_line.dart';
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

  LyricsSearchState stateOf(LyricsHarness h) =>
      h.container.read(lyricsSearchControllerProvider(fakeTarget));

  Finder searchOnCard() => find.descendant(
    of: find.byType(LyricsPickerDisabledSourcesCard),
    matching: find.byType(FilledButton),
  );

  group('card at the end of the results', () {
    testWidgets('names each off source with its hosts and asks nothing', (
      tester,
    ) async {
      await openPickerWith(tester, on: [alpha], off: [beta, gamma]);

      expect(
        find.text("Didn't find the right lyrics? 2 sources are off"),
        findsOneWidget,
      );
      expect(find.text('Beta (beta.example.com)'), findsOneWidget);
      expect(find.text('Gamma (gamma.example.com)'), findsOneWidget);
      expect(beta.searchCalls + gamma.searchCalls, 0);
      // The footer lists only the hosts that were asked.
      expect(find.textContaining('alpha.example.com'), findsWidgets);
      expect(find.textContaining('beta.example.com, '), findsNothing);
    });

    testWidgets('Search asks them, labels results, widens the footer', (
      tester,
    ) async {
      final h = await openPickerWith(tester, on: [alpha], off: [beta, gamma]);

      await tester.tap(searchOnCard());
      await settleUi(tester);

      expect(beta.searchCalls, 1);
      expect(gamma.searchCalls, 1);
      expect(stateOf(h).onDemand, {'beta', 'gamma'});
      expect(find.text('Song b'), findsOneWidget);
      expect(find.text('Source is off'), findsOneWidget);
      expect(find.byType(LyricsPickerDisabledSourcesCard), findsNothing);
      expect(find.textContaining('beta.example.com'), findsWidgets);
    });
  });

  group('no source is on', () {
    testWidgets('lists the off sources and searches all of them', (
      tester,
    ) async {
      await openPickerWith(tester, off: [beta, gamma]);

      expect(find.text('No source is on'), findsOneWidget);
      expect(find.text('Beta (beta.example.com)'), findsOneWidget);
      expect(beta.searchCalls, 0);

      await tester.tap(find.text('Search in 2 disabled sources'));
      await settleUi(tester);

      expect(beta.searchCalls, 1);
      expect(find.text('Song b'), findsOneWidget);
      expect(find.text('No source is on'), findsNothing);
    });

    testWidgets('without any source the old note stays', (tester) async {
      await openPickerWith(tester);
      expect(find.text('No online lyrics source is on.'), findsOneWidget);
      expect(find.byType(LyricsPickerDisabledSourcesCard), findsNothing);
    });
  });

  testWidgets('a failed source searched on request retries alone', (
    tester,
  ) async {
    beta.searchResult = StateError('boom');
    final h = await openPickerWith(tester, on: [alpha], off: [beta]);
    await tester.tap(searchOnCard());
    await settleUi(tester);
    expect(stateOf(h).byProvider['beta']!.phase, ProviderSearchPhase.error);
    final alphaCalls = alpha.searchCalls;

    beta.searchResult = [];
    await tester.tap(
      find.descendant(
        of: find.byType(LyricsPickerFailureLine),
        matching: find.text('Retry'),
      ),
    );
    await settleUi(tester);

    expect(beta.searchCalls, 2);
    expect(alpha.searchCalls, alphaCalls);
    expect(stateOf(h).onDemand, {'beta'});
    expect(find.byType(LyricsPickerDialog), findsOneWidget);
  });

  testWidgets('Search on the card asks the text typed in the field', (
    tester,
  ) async {
    final untitled = LyricsTarget.fromFields(
      uri: '/music/untitled.flac',
      title: null,
      artist: null,
      album: null,
      duration: null,
    );
    await openPickerWith(tester, off: [beta], target: untitled);
    final button = find.descendant(
      of: find.byType(LyricsPickerDisabledSourcesCard),
      matching: find.byType(FilledButton),
    );
    // Blank field: the button is off and nothing is asked.
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'my own words');
    await tester.pump();
    await tester.tap(button);
    await settleUi(tester);

    expect(beta.searchedTexts, ['my own words']);
  });
}
