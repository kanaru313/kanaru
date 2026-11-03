import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/genre_modal/genre_modal_header.dart';
import 'package:kanaru/shared/genre_summaries.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/playlist_cover.dart';
import 'package:material_ui/material_ui.dart';

import 'genre_modal_test_support.dart';

Future<void> _pumpHeader(
  WidgetTester tester, {
  GenreSummary genre = testGenre,
  String displayName = 'Rock',
  int? albumCount,
  int? durationMs,
  VoidCallback? onTap,
}) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: GenreModalHeader(
          genre: genre,
          displayName: displayName,
          albumCount: albumCount,
          durationMs: durationMs,
          onTap: onTap,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('64 px cover, display name, and details with album, songs, duration', (
    tester,
  ) async {
    await _pumpHeader(
      tester,
      albumCount: 3,
      durationMs: 3600000,
    );
    expect(tester.getSize(find.byType(PlaylistCover)), const Size(64, 64));
    expect(find.text('Rock'), findsWidgets);
    expect(find.text('3 albums • 12 songs • 1 h 0 min'), findsOneWidget);
  });

  testWidgets('unknown duration is left out', (tester) async {
    await _pumpHeader(
      tester,
      albumCount: 2,
      durationMs: null,
    );
    expect(find.text('2 albums • 12 songs'), findsOneWidget);
  });

  testWidgets('unknown album count is left out while loading', (tester) async {
    await _pumpHeader(
      tester,
      albumCount: null,
      durationMs: 180000,
    );
    expect(find.text('12 songs • 3 min'), findsOneWidget);
  });

  testWidgets('a tap on the cover or text calls onTap', (tester) async {
    var taps = 0;
    await _pumpHeader(tester, onTap: () => taps++);
    await tester.tap(find.text('Rock'));
    await tester.tap(find.byType(PlaylistCover));
    expect(taps, 2);
  });

  testWidgets('the tappable header takes no keyboard focus', (tester) async {
    await _pumpHeader(tester, onTap: () {});
    final ink = tester.widget<InkWell>(
      find.ancestor(of: find.text('Rock'), matching: find.byType(InkWell)),
    );
    expect(ink.canRequestFocus, isFalse);
  });

  testWidgets('no tap on the genre page; the header is not a button', (
    tester,
  ) async {
    await _pumpHeader(tester, onTap: null);
    expect(
      find.ancestor(of: find.text('Rock'), matching: find.byType(InkWell)),
      findsNothing,
    );
  });

  testWidgets('unknown genre key displays correctly', (tester) async {
    const unknownGenre = GenreSummary(
      key: unknownGenreKey,
      name: '',
      songCount: 5,
      raws: [],
      withoutGenre: true,
    );
    await _pumpHeader(
      tester,
      genre: unknownGenre,
      displayName: 'Tracks without genre',
      albumCount: 1,
      durationMs: 120000,
    );
    expect(find.text('Tracks without genre'), findsOneWidget);
    expect(find.text('1 album • 5 songs • 2 min'), findsOneWidget);
    expect(find.byType(PlaylistCover), findsOneWidget);
  });

  testWidgets('tapping header in modal navigates to genreLocation', (tester) async {
    final host = await pumpGenreHost(tester, links: linksOf());
    await openGenreModalOf(tester);
    await tester.tap(find.text('Rock').first);
    await settleModal(tester);
    expect(host.location, genreLocation('rock'));
  });

  testWidgets('header in modal is not tappable when showGenre is false', (
    tester,
  ) async {
    await pumpGenreHost(tester, links: linksOf(), showGenre: false);
    await openGenreModalOf(tester);
    expect(
      find.ancestor(
        of: find.text('1 album • 12 songs • 36 min'),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });
}
