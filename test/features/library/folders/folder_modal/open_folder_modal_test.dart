import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import 'folder_modal_test_support.dart';

Finder get _modal => find.bySemanticsLabel('Folder options').first;

bool _focusInModal({Finder? within}) {
  final focus = FocusManager.instance.primaryFocus;
  if (focus is FocusScopeNode) return false;
  final ctx = focus?.context;
  if (ctx == null) return false;
  return find
      .descendant(
        of: within ?? find.bySemanticsLabel('Folder options').first,
        matching: find.byElementPredicate((e) => e == ctx),
      )
      .evaluate()
      .isNotEmpty;
}

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets('opens named Folder options with rows and no divider', (
    tester,
  ) async {
    await pumpFolderHost(tester);
    await openFolderModalOf(tester);

    expect(find.bySemanticsLabel('Folder options'), findsWidgets);
    for (final label in [
      'Go to folder',
      'Play all',
      'Shuffle',
      'Add to playlist…',
      'Edit tags',
      'Advanced',
      'Play next',
      'Add to queue',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(
      find.descendant(of: _modal, matching: find.byType(Divider)),
      findsNothing,
    );
  });

  testWidgets('Go to folder is omitted on the folder page', (tester) async {
    await pumpFolderHost(tester, showFolder: false);
    await openFolderModalOf(tester);
    expect(find.text('Go to folder'), findsNothing);
    expect(find.text('Play all'), findsOneWidget);
  });

  testWidgets('Go to folder navigates to folder page', (tester) async {
    final host = await pumpFolderHost(tester);
    await openFolderModalOf(tester);

    await tapFolderRow(tester, 'Go to folder');
    expect(host.location, folderLocation(testFolder.path));
  });

  testWidgets('queue buttons invoke onQueueAction', (tester) async {
    final host = await pumpFolderHost(tester);
    await openFolderModalOf(tester);

    await tapFolderRow(tester, 'Play next');
    await openFolderModalOf(tester);
    await tapFolderRow(tester, 'Add to queue');

    expect(host.queueActions, [QueueAction.playNext, QueueAction.addToQueue]);
  });

  testWidgets(
    'Go to folder trailing button opens file manager with sample path',
    (tester) async {
      final host = await pumpFolderHost(tester);
      await openFolderModalOf(tester);

      final trailingFinder = find.descendant(
        of: folderModalAction('folder'),
        matching: find.byTooltip('Show in file manager'),
      );
      expect(trailingFinder, findsOneWidget);

      await tester.tap(trailingFinder);
      await settleModal(tester);

      expect(host.shownInFileManager, [testStats.samplePath]);
    },
  );

  group('Advanced page', () {
    testWidgets('opens Advanced page, shows items, and Back returns', (
      tester,
    ) async {
      await pumpFolderHost(tester);
      await openFolderModalOf(tester);

      await tapFolderRow(tester, 'Advanced');
      expect(find.text('Show in file manager'), findsNothing);
      expect(find.text('Copy folder path'), findsOneWidget);
      expect(find.text('Exclude from library'), findsOneWidget);
      expect(find.text('Keeps the files'), findsOneWidget);
      expect(find.text('Delete files'), findsOneWidget);
      expect(
        find.text('/m/Rock'),
        findsOneWidget,
      ); // subtitle of copy path
      expect(find.text('Go to folder'), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await settleModal(tester);
      expect(find.text('Go to folder'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
    });

    testWidgets(
      'Copy folder path copies path to clipboard and shows snackbar',
      (tester) async {
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );

        await pumpFolderHost(tester);
        await openFolderModalOf(tester);

        await tapFolderRow(tester, 'Advanced');
        await tapFolderRow(tester, 'Copy folder path');

        expect(copied, testFolder.path);
        expect(find.text('Path copied to clipboard'), findsOneWidget);
      },
    );

    testWidgets('Exclude from library is omitted for root folder', (
      tester,
    ) async {
      final rootFolder = makeFolderNode(path: '/m', rootPath: '/m', name: 'm');
      expect(rootFolder.isRoot, isTrue);

      await pumpFolderHost(tester, folder: rootFolder);
      await openFolderModalOf(tester);

      await tapFolderRow(tester, 'Advanced');
      expect(find.text('Exclude from library'), findsNothing);
      expect(find.text('Show in file manager'), findsNothing);
      expect(find.text('Copy folder path'), findsOneWidget);
      expect(find.text('Delete files'), findsOneWidget);
    });

    testWidgets('Exclude from library calls exclude and handles result', (
      tester,
    ) async {
      final host = await pumpFolderHost(tester);
      await openFolderModalOf(tester);

      await tapFolderRow(tester, 'Advanced');
      await tapFolderRow(tester, 'Exclude from library');

      expect(host.excludedFolders, [testFolder.path]);
      expect(find.bySemanticsLabel('Folder options'), findsNothing);
    });

    testWidgets(
      'Exclude from library shows warning snackbar on conflict result',
      (tester) async {
        final host = await pumpFolderHost(tester);
        host.excludedController.nextResult = (
          rejection: null,
          conflict: ExclusionConflict.alreadyExcluded,
        );
        await openFolderModalOf(tester);

        await tapFolderRow(tester, 'Advanced');
        await tapFolderRow(tester, 'Exclude from library');

        expect(host.excludedFolders, [testFolder.path]);
        expect(find.text('That folder is already excluded.'), findsOneWidget);
      },
    );

    testWidgets('Delete files shows coming soon message', (tester) async {
      await pumpFolderHost(tester);
      await openFolderModalOf(tester);

      await tapFolderRow(tester, 'Advanced');
      await tapFolderRow(tester, 'Delete files');

      expect(find.textContaining("isn't available yet"), findsOneWidget);
    });
  });

  group('Keyboard navigation and focus', () {
    testWidgets('Menu key focuses first row; Enter acts', (tester) async {
      final host = await pumpFolderHost(tester);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await settleModal(tester);

      expect(_focusInModal(within: folderModalAction('folder')), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleModal(tester);
      expect(host.location, folderLocation(testFolder.path));
    });

    testWidgets('on folder page first focused row is Play all', (tester) async {
      await pumpFolderHost(tester, showFolder: false);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await settleModal(tester);

      expect(_focusInModal(within: folderModalAction('play-all')), isTrue);
    });

    testWidgets(
      'Esc on Advanced page goes back, Esc on root page closes modal',
      (tester) async {
        await pumpFolderHost(tester);
        await openFolderModalOf(tester);

        await tapFolderRow(tester, 'Advanced');
        expect(find.text('Delete files'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settleModal(tester);
        expect(find.text('Advanced'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settleModal(tester);
        expect(find.text('Advanced'), findsNothing);
      },
    );

    testWidgets('right click opens with no focus inside modal', (tester) async {
      await pumpFolderHost(tester);
      await tester.tap(find.text('tile'), buttons: kSecondaryButton);
      await settleModal(tester);
      expect(_focusInModal(), isFalse);
    });

    testWidgets('Enter on focused more button focuses first row', (
      tester,
    ) async {
      await pumpFolderHost(tester, withMoreButton: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleModal(tester);

      expect(_focusInModal(within: folderModalAction('folder')), isTrue);
    });

    testWidgets('click on more button opens with no focus inside modal', (
      tester,
    ) async {
      await pumpFolderHost(tester, withMoreButton: true);
      await tester.tap(find.byTooltip('More options'));
      await settleModal(tester);

      expect(find.text('Go to folder'), findsOneWidget);
      expect(_focusInModal(), isFalse);
    });
  });

  group('Gone state', () {
    testWidgets('disables playback and playlist rows when stats are null', (
      tester,
    ) async {
      await pumpFolderHost(tester, stats: null);
      await openFolderModalOf(tester);

      final playAllInk = tester.widget<InkWell>(
        find.descendant(
          of: folderModalAction('play-all'),
          matching: find.byType(InkWell),
        ),
      );
      expect(playAllInk.onTap, isNull);

      final shuffleInk = tester.widget<InkWell>(
        find.descendant(
          of: folderModalAction('shuffle'),
          matching: find.byType(InkWell),
        ),
      );
      expect(shuffleInk.onTap, isNull);

      final addToPlaylistInk = tester.widget<InkWell>(
        find.descendant(
          of: folderModalAction('add-to-playlist'),
          matching: find.byType(InkWell),
        ),
      );
      expect(addToPlaylistInk.onTap, isNull);

      // Footer buttons are disabled
      final playNext = tester.widget<InkWell>(
        find.byKey(const ValueKey('folder-modal-play-next')),
      );
      expect(playNext.onTap, isNull);

      final addToQueue = tester.widget<InkWell>(
        find.byKey(const ValueKey('folder-modal-add-to-queue')),
      );
      expect(addToQueue.onTap, isNull);
    });
  });
}
