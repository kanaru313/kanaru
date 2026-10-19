import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/library_roots_controller.dart';
import 'package:kanaru/features/library/onboarding/onboarding_screen.dart';
import 'package:kanaru/features/library/songs/songs_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'library_test_harness.dart';

class _ThrowingRootsController implements LibraryRootsController {
  @override
  Future<AddRootsResult> addRoots(List<String> paths) =>
      Future.error(StateError('boom'));
}

void main() {
  Finder start() => find.widgetWithText(FilledButton, 'Start');

  testWidgets('shows the checked suggestion and enables Start', (tester) async {
    final h = LibraryHarness(suggestion: '/music');
    await h.pump(tester);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('/music'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    expect(tester.widget<FilledButton>(start()).onPressed, isNotNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(tester.widget<FilledButton>(start()).onPressed, isNull);
  });

  testWidgets('Start is disabled without any folder', (tester) async {
    final h = LibraryHarness();
    await h.pump(tester);

    expect(find.text('No folder chosen yet.'), findsOneWidget);
    expect(tester.widget<FilledButton>(start()).onPressed, isNull);
  });

  testWidgets('a folder inside one already chosen is refused', (tester) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    final nested = h.folder('music/rock');
    h.picks.addAll([music, nested, music]);
    await h.pump(tester);

    Future<void> add() async {
      await tester.tap(find.text('Add folder…'));
      await settleIo(tester);
    }

    await add();
    expect(find.text(music), findsOneWidget);

    await add();
    expect(find.text(nested), findsNothing);
    expect(
      find.text('$nested overlaps a folder that is already added'),
      findsOneWidget,
    );

    await add();
    expect(find.text('$music is already added'), findsOneWidget);
    expect(find.text(music), findsOneWidget);
  });

  testWidgets('Start stores the root, scans and opens Songs', (tester) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    h.touch(music, 'a.mp3');
    h.picks.add(music);
    await h.pump(tester);

    await tester.tap(find.text('Add folder…'));
    await settleIo(tester);
    await tester.tap(start());
    await settleIo(tester);

    expect((await tester.runAsync(h.db.roots))!.single.path, music);
    expect(h.reader.readCount, 1);
    expect(find.byType(SongsScreen), findsOneWidget);
    expect(find.text('A.MP3'), findsOneWidget);

    // Once a folder exists the welcome screen can no longer be reached.
    expect(h.container.read(libraryHasRootsProvider), isTrue);
    h.container.read(routerProvider).go('/welcome');
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Your library is empty'), findsOneWidget);
  });

  testWidgets('a rejected folder keeps the screen open', (tester) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    h.picks.add(music);
    await h.pump(tester);
    await tester.tap(find.text('Add folder…'));
    await settleIo(tester);
    // The folder disappears before Start.
    await tester.runAsync(() async => Directory(music).deleteSync());

    await tester.tap(start());
    await settleIo(tester);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('$music was not found'), findsOneWidget);
    expect(await tester.runAsync(h.db.roots), isEmpty);
  });

  testWidgets('with one folder stored and one refused it still scans', (
    tester,
  ) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    final gone = h.folder('gone');
    h.touch(music, 'a.mp3');
    h.picks.addAll([music, gone]);
    await h.pump(tester);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Add folder…'));
      await settleIo(tester);
    }
    // One folder disappears before Start.
    await tester.runAsync(() async => Directory(gone).deleteSync());

    await tester.tap(start());
    await settleIo(tester, rounds: 12);

    expect((await tester.runAsync(h.db.roots))!.single.path, music);
    expect(find.byType(SongsScreen), findsOneWidget);
    expect(h.reader.readCount, 1, reason: 'the stored folder is scanned');
    expect(find.text('$gone was not found'), findsOneWidget);
  });

  testWidgets('an unexpected error re-enables the buttons and says so', (
    tester,
  ) async {
    final h = LibraryHarness(
      overrides: [
        libraryRootsControllerProvider.overrideWithValue(
          _ThrowingRootsController(),
        ),
      ],
    );
    h.picks.add(h.folder('music'));
    await h.pump(tester);
    await tester.tap(find.text('Add folder…'));
    await settleIo(tester);

    await tester.tap(start());
    await settleIo(tester);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(
      find.text('Something went wrong. See the log for details.'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(start()).onPressed, isNotNull);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Later'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Later goes to Home and leaves the library empty', (
    tester,
  ) async {
    final h = LibraryHarness(suggestion: '/music');
    await h.pump(tester);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Your library is empty'), findsOneWidget);
    expect(await tester.runAsync(h.db.roots), isEmpty);
  });

  testWidgets('opens on Home when the library database is unavailable', (
    tester,
  ) async {
    final h = LibraryHarness(hasDatabase: false);
    await h.pump(tester);

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Your library is empty'), findsOneWidget);
  });

  testWidgets('opens on Home when a root already exists', (tester) async {
    final h = LibraryHarness();
    await h.pump(tester, hasRoots: true);

    expect(find.byType(OnboardingScreen), findsNothing);
  });
}
