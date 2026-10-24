import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/languages/language_grid_tile.dart';
import 'package:kanaru/features/library/languages/language_tile.dart';
import 'package:kanaru/shared/library_route_keys.dart';

import '../browse_test_data.dart';
import '../library_test_harness.dart';
import '../list_view_modes_override.dart';
import 'language_test_data.dart';

const _tracks = [
  LangTrack('e1', 'eng'),
  LangTrack('e2', 'en-US'),
  LangTrack('ev', 'eng; vie'),
  LangTrack('v1', 'vie'),
  LangTrack('inst', 'zxx'),
  LangTrack('lost', 'und'),
  LangTrack('none', null),
];

void main() {
  testWidgets('lists the languages with counts, hiding und and untagged', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithLanguages(tester, h, _tracks, location: languagesPath);

    // English (region merged), Vietnamese, No lyrics.
    expect(find.byType(LanguageTile), findsNWidgets(3));
    expect(find.text('English'), findsOneWidget);
    expect(find.text('3 songs'), findsOneWidget);
    expect(find.text('Vietnamese'), findsOneWidget);
    expect(find.text('2 songs'), findsOneWidget);
    expect(find.text('No lyrics'), findsOneWidget);
    expect(find.text('1 song'), findsOneWidget);
    expect(find.textContaining('nknown'), findsNothing);
    expect(find.text('UND'), findsNothing);
  });

  testWidgets('opens as a grid by default and the toggle shows the list', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithLanguages(tester, h, _tracks, location: languagesPath);

    expect(find.byType(LanguageGridTile), findsNWidgets(3));
    expect(find.byType(LanguageTile), findsNothing);

    await tester.tap(find.byTooltip('Grid'));
    await tester.pumpAndSettle();
    expect(find.byType(LanguageTile), findsNWidgets(3));
  });

  testWidgets('tapping a language opens its page', (tester) async {
    final h = LibraryHarness();
    await openWithLanguages(tester, h, _tracks, location: languagesPath);

    await tester.tap(find.text('Vietnamese'));
    await tester.pumpAndSettle();

    expect(location(h), languageLocation('vie'));
  });

  testWidgets('without language tags the page explains where they come from', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithLanguages(tester, h, const [
      LangTrack('a', null),
    ], location: languagesPath);

    expect(find.text('No languages yet'), findsOneWidget);
    expect(find.textContaining('TLAN'), findsOneWidget);
    expect(find.byType(LanguageGridTile), findsNothing);
  });

  testWidgets('without a music folder it points to Songs', (tester) async {
    final h = LibraryHarness();
    await h.pump(tester);
    goTo(tester, h, languagesPath);
    await tester.pumpAndSettle();

    expect(find.text('Add a music folder in Songs.'), findsOneWidget);
    expect(find.byTooltip('List'), findsNothing);
    expect(find.byTooltip('Grid'), findsNothing);
  });
}
