import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_match.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_search_state.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_preview.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_result_tile.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_results_pane.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/fake_lyrics_provider.dart';

// A failure line holds the View log button, which reads providers.
Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  ),
);

RankedCandidate _ranked(Duration length) {
  final candidate = fakeCandidate(duration: length);
  const query = LyricsQuery(
    title: 'Song',
    artist: 'Artist',
    duration: Duration(seconds: 200),
  );
  return RankedCandidate(candidate, matchCandidate(query, candidate));
}

void main() {
  _rejectedAndClipTests();
  group('length difference', () {
    testWidgets('3.4 s over shows a rounded-up warning', (tester) async {
      await _pump(
        tester,
        LyricsPickerResultTile(
          result: _ranked(const Duration(milliseconds: 203400)),
          selected: false,
          onTap: () {},
        ),
      );

      expect(find.text('±4s'), findsOneWidget);
    });

    testWidgets('exactly 3 s is not warned', (tester) async {
      await _pump(
        tester,
        LyricsPickerResultTile(
          result: _ranked(const Duration(seconds: 203)),
          selected: false,
          onTap: () {},
        ),
      );

      expect(find.textContaining('±'), findsNothing);
    });
  });

  group('consent withdrawn', () {
    Future<void> pumpPane(WidgetTester tester, LyricsFetchKind kind) => _pump(
      tester,
      LyricsPickerResultsPane(
        state: LyricsSearchState(
          query: 'x',
          byProvider: {
            'fake': ProviderSearchState(ProviderSearchPhase.error, kind),
          },
        ),
        providerNames: const {'fake': 'Fake'},
        onSelect: (_) {},
        onRetry: () {},
      ),
    );

    testWidgets('says so and offers no Retry', (tester) async {
      await pumpPane(tester, LyricsFetchKind.notConsented);

      expect(
        find.text("You haven't allowed lyrics search on Fake."),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a network error keeps Retry', (tester) async {
      await pumpPane(tester, LyricsFetchKind.network);

      expect(find.text("Couldn't reach Fake"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a rate limit says the service is busy and keeps Retry', (
      tester,
    ) async {
      await pumpPane(tester, LyricsFetchKind.rateLimited);

      expect(find.text('Fake is busy. Try again in a moment.'), findsOneWidget);
      expect(find.text("Couldn't reach Fake"), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  testWidgets('an unreadable answer says so and keeps Retry', (tester) async {
    await _pump(
      tester,
      LyricsPickerResultsPane(
        state: const LyricsSearchState(
          query: 'x',
          byProvider: {
            'fake': ProviderSearchState(
              ProviderSearchPhase.error,
              LyricsFetchKind.invalidResponse,
            ),
          },
        ),
        providerNames: const {'fake': 'Fake'},
        onSelect: (_) {},
        onRetry: () {},
      ),
    );

    expect(
      find.text('Fake answered but Kanaru could not read it'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a blank query before any search shows the note', (tester) async {
    await _pump(
      tester,
      LyricsPickerResultsPane(
        state: const LyricsSearchState(query: ''),
        providerNames: const {},
        onSelect: (_) {},
        onRetry: () {},
      ),
    );

    expect(
      find.text('Type the artist and title, then press Search'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('synced text that does not parse previews the plain text', (
    tester,
  ) async {
    await _pump(
      tester,
      LyricsPickerPreview(
        candidate: fakeCandidate(
          body: const LyricsBody(syncedLrc: '[ar:x]', plain: 'only plain'),
        ),
      ),
    );

    expect(find.text('only plain'), findsOneWidget);
  });
}

RankedCandidate _rejected() {
  final candidate = fakeCandidate();
  const query = LyricsQuery(
    title: 'Song',
    artist: 'Artist',
    duration: Duration(seconds: 200),
  );
  return RankedCandidate(
    candidate,
    matchCandidate(query, candidate, rejected: {candidate.ref}),
  );
}

void _rejectedAndClipTests() {
  group('rejected result', () {
    testWidgets('shows the Rejected label and no Good match', (tester) async {
      await _pump(
        tester,
        LyricsPickerResultTile(
          result: _rejected(),
          selected: false,
          onTap: () {},
        ),
      );

      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Good match'), findsNothing);
    });

    testWidgets('a normal result has no label', (tester) async {
      await _pump(
        tester,
        LyricsPickerResultTile(
          result: _ranked(const Duration(seconds: 200)),
          selected: false,
          onTap: () {},
        ),
      );

      expect(find.text('Rejected'), findsNothing);
    });
  });

  group('results list clipping', () {
    testWidgets('ink and hover stay inside a clipped Material', (tester) async {
      await _pump(
        tester,
        SizedBox(
          height: 200,
          child: LyricsPickerResultsPane(
            state: LyricsSearchState(
              query: 'x',
              results: [
                for (var i = 0; i < 10; i++)
                  _ranked(const Duration(seconds: 200)),
              ],
              selected: 0,
            ),
            providerNames: const {},
            onSelect: (_) {},
            onRetry: () {},
          ),
        ),
      );

      final list = find.byType(ListView);
      final material = find.ancestor(of: list, matching: find.byType(Material));
      final clip = find.ancestor(of: list, matching: find.byType(ClipRect));
      expect(material, findsWidgets);
      expect(clip, findsOneWidget);
      // The nearest Material above the list sits inside the clip.
      final nearest = tester.element(material.first).widget as Material;
      expect(nearest.type, MaterialType.transparency);
      expect(
        find.descendant(of: clip, matching: material.first),
        findsOneWidget,
      );
    });
  });
}
