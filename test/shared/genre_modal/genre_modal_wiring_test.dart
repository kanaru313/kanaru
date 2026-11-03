import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/genres/genre_grid_tile.dart';
import 'package:kanaru/features/library/genres/genre_header.dart';
import 'package:kanaru/features/library/genres/genre_tile.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/genre_modal/genre_modal_links.dart';
import 'package:kanaru/shared/genre_modal/genre_more_button.dart';
import 'package:kanaru/shared/genre_summaries.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import 'genre_modal_test_support.dart';

Finder get _modal => find.bySemanticsLabel('Genre options');

Future<void> _pumpGridTile(
  WidgetTester tester, {
  GenreSummary genre = testGenre,
  ValueChanged<QueueAction>? onQueueAction,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      genreModalLinksProvider(genre).overrideWith((ref) async => linksOf()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            height: 260,
            child: GenreGridTile(
              genre: genre,
              onTap: () {},
              onQueueAction: onQueueAction ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _pumpTile(
  WidgetTester tester, {
  GenreSummary genre = testGenre,
  bool withQueue = true,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      genreModalLinksProvider(genre).overrideWith((ref) async => linksOf()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: GenreTile(
          genre: genre,
          onTap: () {},
          onQueueAction: withQueue ? (_) {} : null,
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets('secondary tap on GenreGridTile opens Genre options modal', (
    tester,
  ) async {
    await _pumpGridTile(tester);
    await tester.tap(find.byType(GenreGridTile), buttons: kSecondaryButton);
    await settleModal(tester);

    expect(_modal, findsWidgets);
  });

  testWidgets('secondary tap on GenreTile opens Genre options modal', (
    tester,
  ) async {
    await _pumpTile(tester);
    await tester.tap(find.byType(GenreTile), buttons: kSecondaryButton);
    await settleModal(tester);

    expect(_modal, findsWidgets);
  });

  testWidgets('GenreMoreButton is shown only when onQueueAction is provided', (
    tester,
  ) async {
    await _pumpTile(tester, withQueue: true);
    expect(find.byType(GenreMoreButton), findsOneWidget);

    await _pumpTile(tester, withQueue: false);
    expect(find.byType(GenreMoreButton), findsNothing);
  });

  testWidgets('tap on GenreMoreButton opens Genre options modal', (
    tester,
  ) async {
    await _pumpTile(tester, withQueue: true);
    await tester.tap(find.byType(GenreMoreButton));
    await settleModal(tester);

    expect(_modal, findsWidgets);
  });

  testWidgets(
    'tap on more button in GenreHeader opens modal with showGenre false',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            genreModalLinksProvider(testGenre)
                .overrideWith((ref) async => linksOf()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: GenreHeader(
                genre: testGenre,
                albumCount: 2,
                onPlay: () {},
                onShuffle: () {},
                onQueueAction: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(GenreMoreButton));
      await settleModal(tester);

      expect(_modal, findsWidgets);
      // 'Go to genre' row must be omitted
      expect(find.text('Go to genre'), findsNothing);
    },
  );

  testWidgets('Enter on GenreMoreButton opens modal with focus on first row', (
    tester,
  ) async {
    await _pumpTile(tester, withQueue: true);
    // Tab twice: first to the ListTile, then to the trailing GenreMoreButton
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleModal(tester);

    expect(_modal, findsWidgets);
    final ctx = FocusManager.instance.primaryFocus?.context;
    expect(
      find.descendant(
        of: _modal.first,
        matching: find.byElementPredicate((e) => e == ctx),
      ),
      findsWidgets,
    );
  });

  testWidgets('Menu key on GenreTile opens Genre options modal', (
    tester,
  ) async {
    await _pumpTile(tester, withQueue: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await settleModal(tester);

    expect(_modal, findsWidgets);
  });

  testWidgets('Shift+F10 on GenreTile opens Genre options modal', (
    tester,
  ) async {
    await _pumpTile(tester, withQueue: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await settleModal(tester);

    expect(_modal, findsWidgets);
  });

  testWidgets('Menu key on GenreGridTile opens Genre options modal', (
    tester,
  ) async {
    await _pumpGridTile(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await settleModal(tester);

    expect(_modal, findsWidgets);
  });

  testWidgets('Shift+F10 on GenreGridTile opens Genre options modal', (
    tester,
  ) async {
    await _pumpGridTile(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await settleModal(tester);

    expect(_modal, findsWidgets);
  });
}
