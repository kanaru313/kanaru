import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:material_ui/material_ui.dart';

import '../library_test_harness.dart';
import 'hidden_folders_support.dart';

void main() {
  testWidgets('a hidden folder opens only with the eye on, inside a root', (
    tester,
  ) async {
    final h = LibraryHarness();
    final root = await openMusic(
      tester,
      h,
      prepare: (root) {
        File('$root/.secret/inner/deep.mp3').createSync(recursive: true);
        File('$root/.secret/song.mp3').writeAsStringSync('x');
      },
    );
    final notFound = find.text('Folder not found');

    await openPage(tester, h, '$root/.secret', notFound);
    expect(notFound, findsOneWidget);

    await toggleEye(tester, h, until: find.text('song'));
    expect(notFound, findsNothing);
    expect(find.text('inner'), findsOneWidget);
    expect(find.text('song'), findsOneWidget);

    await toggleEye(tester, h, until: notFound);
    expect(notFound, findsOneWidget);
  });

  testWidgets('tampered paths never open a page, even with the eye on', (
    tester,
  ) async {
    final h = LibraryHarness();
    late String outside;
    late String linked;
    final root = await openMusic(
      tester,
      h,
      prepare: (root) {
        outside = h.folder('elsewhere/.x');
        File('$outside/o.mp3').writeAsStringSync('x');
        File('$root/.real/r.mp3').createSync(recursive: true);
        // A link inside the music folder that leads out of it.
        Link('$root/.link').createSync(outside);
        linked = '$root/.link';
      },
    );
    await toggleEye(tester, h);
    final notFound = find.text('Folder not found');

    for (final path in [
      outside,
      '$root/../elsewhere/.x',
      '$root/.real/../.real',
      '$root/.real\u0000',
      '$root/.real/',
      linked,
      '$linked/sub',
    ]) {
      await openPage(tester, h, path, notFound);
      expect(notFound, findsOneWidget, reason: path);
    }

    await openPage(tester, h, '$root/.real', find.text('r'));
    expect(find.text('r'), findsOneWidget);
  });

  testWidgets('Play on a hidden folder page queues its files', (tester) async {
    final h = LibraryHarness();
    final root = await openMusic(
      tester,
      h,
      prepare: (root) {
        File('$root/.secret/b.mp3').createSync(recursive: true);
        File('$root/.secret/a.mp3').createSync();
      },
    );
    await toggleEye(tester, h);
    await openPage(tester, h, '$root/.secret', find.text('b'));

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();

    expect(
      [
        for (final t in h.container.read(playerServiceProvider).queue.original)
          t.title,
      ],
      ['a', 'b'],
    );
  });
}
