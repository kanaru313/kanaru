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

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
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
        find.text(
          'Online lyrics are turned off for Fake. Allow it in Settings.',
        ),
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
