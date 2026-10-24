import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/folders/folder_list_tile.dart';
import 'package:kanaru/features/library/folders/show_hidden_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../library_test_harness.dart';
import '../list_view_modes_override.dart';
import 'hidden_folders_support.dart';

void main() {
  Finder eye(String tooltip) => find.byTooltip(tooltip);

  testWidgets('the eye shows in the tree view and toggles its tooltip', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openMusic(tester, h, location: (_) => '/folders');

    expect(eye('Show hidden items'), findsOneWidget);
    await tester.tap(eye('Show hidden items'));
    await tester.pumpAndSettle();

    expect(eye('Hide hidden items'), findsOneWidget);
    expect(eye('Show hidden items'), findsNothing);
  });

  testWidgets('the eye is not in the flat view', (tester) async {
    final h = LibraryHarness();
    await openMusic(tester, h, location: (_) => '/folders');

    await tester.tap(find.byTooltip('Folder tree'));
    await tester.pumpAndSettle();

    expect(eye('Show hidden items'), findsNothing);
    expect(eye('Hide hidden items'), findsNothing);
  });

  testWidgets('a folder page has the eye too, sharing the state', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openMusic(tester, h);

    expect(eye('Show hidden items'), findsOneWidget);
    await tester.tap(eye('Show hidden items'));
    await settleIo(tester, h);

    expect(h.container.read(showHiddenFoldersProvider), isTrue);
    expect(eye('Hide hidden items'), findsOneWidget);
  });

  testWidgets('a hidden subfolder appears dimmed and tagged with the eye on', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openMusic(
      tester,
      h,
      prepare: (root) => Directory('$root/.secret').createSync(),
    );

    expect(find.text('.secret'), findsNothing);
    await toggleEye(tester, h, until: find.text('.secret'));

    expect(find.widgetWithText(FolderListTile, '.secret'), findsOneWidget);
    expect(find.text('Hidden'), findsOneWidget);
    final dimmed = find.ancestor(
      of: find.text('.secret'),
      matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity < 1),
    );
    expect(dimmed, findsOneWidget);

    await toggleEye(tester, h);
    expect(find.text('.secret'), findsNothing);
  });

  testWidgets('a hidden song on the disk plays as a file by its name', (
    tester,
  ) async {
    final h = LibraryHarness();
    final root = await openMusic(
      tester,
      h,
      prepare: (root) => File('$root/.demo take.mp3').writeAsStringSync('x'),
    );
    await toggleEye(tester, h, until: find.text('.demo take'));

    await tester.tap(find.text('.demo take'));
    await tester.pump();

    final queue = h.container.read(playerServiceProvider).queue;
    expect([for (final t in queue.original) t.title], ['a', '.demo take']);
    expect(queue.current?.title, '.demo take');
    expect(queue.current?.uri, '$root/.demo take.mp3');
    expect(queue.current?.artist, isNull);
  });

  testWidgets('a dot-named library song is hidden with the eye off', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openMusic(tester, h, songs: const ['a.flac', '.b.flac']);

    expect(find.text('a'), findsOneWidget);
    expect(find.text('.b'), findsNothing);

    await toggleEye(tester, h);

    expect(find.text('.b'), findsOneWidget);
    expect(find.text('Hidden'), findsOneWidget);
  });

  testWidgets('with the eye off folder Play still queues a dot-named song', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openMusic(tester, h, songs: const ['a.flac', '.b.flac']);

    expect(find.text('.b'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await settleIo(tester, h);

    expect(
      [
        for (final t in h.container.read(playerServiceProvider).queue.original)
          t.title,
      ],
      ['.b', 'a'],
    );
  });
}
