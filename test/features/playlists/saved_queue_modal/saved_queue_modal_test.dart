import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/queue_history_queries.dart';
import 'package:kanaru/core/database/queue_history_writes.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/playlists/playlist_modal/playlist_more_button.dart';
import 'package:kanaru/features/playlists/queue_history_screen.dart';
import 'package:kanaru/features/playlists/saved_queue_modal/saved_queue_more_button.dart';
import 'package:kanaru/shared/m3u/m3u_save_picker.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../library/browse_test_data.dart';
import '../../library/library_test_harness.dart';
import '../add_to_playlist_test_support.dart';
import '../playlist_test_data.dart';
import '../playlist_modal/playlist_modal_test_support.dart';

void main() {
  late Directory tmp;
  late LibraryHarness h;
  final suggested = <String>[];

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kanaru-modal-queue');
    suggested.clear();
    h = LibraryHarness(
      refreshInterval: Duration.zero,
      overrides: [
        m3uSavePickerProvider.overrideWithValue((name) async {
          suggested.add(name);
          return '${tmp.path}/out.m3u8';
        }),
      ],
    );
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  final savedAt = DateTime(2026, 10, 22, 21, 30).millisecondsSinceEpoch;
  const queueName = 'Oct 22, 2026 · 21:30';

  Future<int> seed(
    WidgetTester tester, {
    List<String> titles = const ['a', 'b'],
    List<String> missing = const [],
    String location = '/queue-history',
    bool open = true,
  }) async {
    await openWithTracks(tester, h, [
      for (final t in ['a', 'b', 'c']) TestTrack(t, durationMs: 120000),
    ], location: '/home');
    final paths = await trackPaths(tester, h);
    await tester.runAsync(
      () => h.db.recordQueueSnapshot([
        for (final t in titles) paths[t]!,
        ...missing,
      ], now: savedAt),
    );
    final all = await tester.runAsync(h.db.queueSnapshots);
    final id = all!.single.id;
    goTo(
      tester,
      h,
      location == '/queue-history' ? location : '/queue-history/$id',
    );
    await settleDb(tester);
    return id;
  }

  Future<void> openRowModal(WidgetTester tester) async {
    await tester.tap(find.byType(QueueSnapshotRow), buttons: kSecondaryButton);
    await settleModal(tester);
  }

  Future<void> openAdvanced(WidgetTester tester) async {
    await tapModalAction(tester, 'advanced');
  }

  bool enabled(WidgetTester tester, String id) {
    final tile = find.descendant(
      of: modalAction(id),
      matching: find.byType(InkWell),
    );
    return tester.widget<InkWell>(tile.first).onTap != null;
  }

  group('Queues row', () {
    testWidgets('right click shows the sections of a saved queue', (
      tester,
    ) async {
      await seed(tester, missing: ['/gone/x.flac']);
      await openRowModal(tester);

      final header = find.byType(ContextModalHeader);
      expect(
        find.descendant(of: header, matching: find.text(queueName)),
        findsOneWidget,
      );
      // Two library songs of 2 min, one missing file.
      expect(
        find.descendant(of: header, matching: find.textContaining('4 min')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.textContaining('1 missing')),
        findsOneWidget,
      );
      for (final id in [
        'go-to-playlist',
        'play-all',
        'shuffle',
        'add-to-playlist',
        'advanced',
        'delete',
      ]) {
        expect(modalAction(id), findsOneWidget, reason: id);
      }
      expect(find.text('Go to queue'), findsOneWidget);
      expect(find.text('Delete queue'), findsOneWidget);
      expect(modalAction('edit'), findsNothing);
      expect(find.byTooltip('Change playlist cover'), findsNothing);
    });

    testWidgets('the ⋮ button opens it', (tester) async {
      await seed(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(QueueSnapshotRow),
          matching: find.byType(SavedQueueMoreButton),
        ),
      );
      await settleModal(tester);
      expect(modalAction('play-all'), findsOneWidget);
    });

    testWidgets('a long press opens it', (tester) async {
      await seed(tester);
      await tester.longPress(find.byType(QueueSnapshotRow));
      await settleModal(tester);
      expect(modalAction('play-all'), findsOneWidget);
    });

    testWidgets('the Menu key opens it and focuses the first row', (
      tester,
    ) async {
      await seed(tester);
      // The nearest focus node above the row's title is the ink well's.
      Focus.of(tester.element(find.text(queueName))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await settleModal(tester);

      expect(modalAction('play-all'), findsOneWidget);
      final focus = FocusManager.instance.primaryFocus!;
      final firstRow = tester.element(modalAction('go-to-playlist'));
      var inside = false;
      focus.context!.visitAncestorElements((e) {
        if (e == firstRow) inside = true;
        return !inside;
      });
      expect(inside, isTrue, reason: 'focus is in the Go to queue row');
    });

    testWidgets('Shuffle and Add to queue act on the saved songs', (
      tester,
    ) async {
      await seed(tester, titles: ['a', 'b', 'c']);
      await openRowModal(tester);
      await tapModalAction(tester, 'shuffle');
      await settleDb(tester);
      expect(h.container.read(playerServiceProvider).queue.shuffled, isTrue);
      expect(queueTitles(h)..sort(), ['a', 'b', 'c']);

      await openRowModal(tester);
      await tester.tap(
        find.byKey(const ValueKey('saved-queue-modal-add-to-queue')),
      );
      await settleDb(tester);
      expect(queueTitles(h), hasLength(6));
    });

    testWidgets('Go to queue opens the page of the queue', (tester) async {
      final id = await seed(tester);
      await openRowModal(tester);
      await tapModalAction(tester, 'go-to-playlist');
      expect(location(h), '/queue-history/$id');
    });

    testWidgets('Advanced has no Duplicate and no repeats clean-up', (
      tester,
    ) async {
      await seed(tester, titles: ['a', 'a']);
      await openRowModal(tester);
      await openAdvanced(tester);
      expect(modalAction('add-all-to-favorites'), findsOneWidget);
      expect(modalAction('export-m3u'), findsOneWidget);
      expect(modalAction('export-relative'), findsNothing);
      expect(find.byTooltip('Export with relative paths'), findsOneWidget);
      expect(modalAction('duplicate'), findsNothing);
      expect(modalAction('remove-duplicates'), findsNothing);
      expect(modalAction('remove-missing'), findsNothing);
    });

    testWidgets('a queue with nothing playable greys the acting rows', (
      tester,
    ) async {
      await seed(tester, titles: [], missing: ['/gone/x.flac', '/gone/y.flac']);
      await openRowModal(tester);
      expect(
        find.text('None of these songs are in your library'),
        findsOneWidget,
      );
      expect(enabled(tester, 'play-all'), isFalse);
      expect(enabled(tester, 'add-to-playlist'), isFalse);
      expect(enabled(tester, 'delete'), isTrue);
    });
  });

  group('which modal a page opens', () {
    testWidgets('the ⋮ of a saved queue page opens the saved-queue modal', (
      tester,
    ) async {
      await seed(tester, location: 'page');
      await tester.tap(find.byType(SavedQueueMoreButton));
      await settleModal(tester);

      expect(find.text('Delete queue'), findsOneWidget);
      expect(modalAction('play-all'), findsOneWidget);
      expect(modalAction('go-to-playlist'), findsNothing);
      expect(modalAction('edit'), findsNothing);
    });

    testWidgets('the ⋮ of a playlist page still opens the playlist modal', (
      tester,
    ) async {
      await openMix(tester, h);
      await tester.tap(find.byType(PlaylistMoreButton));
      await settleModal(tester);

      expect(modalAction('edit'), findsOneWidget);
      expect(find.text('Delete playlist'), findsOneWidget);
      expect(find.text('Delete queue'), findsNothing);
    });
  });

  group('Delete queue', () {
    testWidgets('cancel returns to the modal and keeps the queue', (
      tester,
    ) async {
      final id = await seed(tester);
      await openRowModal(tester);
      await tester.tap(modalAction('delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this queue?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleModal(tester);

      expect(modalAction('delete'), findsOneWidget);
      expect(
        await tester.runAsync(() => h.db.queueSnapshotPaths(id)),
        isNotEmpty,
      );
    });

    testWidgets('confirm from the list deletes it and says so', (tester) async {
      final id = await seed(tester);
      await openRowModal(tester);
      await tester.tap(modalAction('delete'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await settleDb(tester);

      expect(await tester.runAsync(() => h.db.queueSnapshotPaths(id)), isEmpty);
      expect(find.text('Queue deleted'), findsOneWidget);
      expect(find.text('No queue history yet'), findsOneWidget);
    });

    testWidgets('confirm on the page lands on the Queues list', (tester) async {
      final id = await seed(tester, location: 'page');
      expect(location(h), '/queue-history/$id');
      await tester.tap(find.byType(SavedQueueMoreButton));
      await settleModal(tester);
      expect(modalAction('go-to-playlist'), findsNothing);
      await tester.tap(modalAction('delete'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await settleDb(tester);

      expect(location(h), '/queue-history');
      expect(find.text('Queue not found'), findsNothing);
      expect(await tester.runAsync(() => h.db.queueSnapshotPaths(id)), isEmpty);
    });
  });

  group('Remove missing songs', () {
    testWidgets('asks above the modal; Cancel keeps it open and the entries', (
      tester,
    ) async {
      final id = await seed(tester, missing: ['/gone/x.flac']);
      await openRowModal(tester);
      await openAdvanced(tester);
      await tester.tap(modalAction('remove-missing'));
      await tester.pumpAndSettle();
      expect(find.text('Remove missing songs?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleModal(tester);
      expect(modalAction('remove-missing'), findsOneWidget);
      expect(await storedPaths(tester, h, id), hasLength(3));
    });

    testWidgets('confirming removes only the missing ones', (tester) async {
      final id = await seed(tester, missing: ['/gone/x.flac']);
      await openRowModal(tester);
      await openAdvanced(tester);
      await tester.tap(modalAction('remove-missing'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Remove missing songs'),
        ),
      );
      await settleDb(tester);
      expect(modalAction('remove-missing'), findsNothing);
      expect(await storedPaths(tester, h, id), hasLength(2));
    });
  });

  group('copy and export', () {
    testWidgets('Add to playlist suggests the queue name for a new one', (
      tester,
    ) async {
      await seed(tester, missing: ['/gone/x.flac']);
      await openRowModal(tester);
      await tester.tap(modalAction('add-to-playlist'));
      await settleDb(tester);
      await tester.tap(find.text('New playlist…'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, queueName), findsOneWidget);
    });

    testWidgets('Add to playlist copies the missing entries too', (
      tester,
    ) async {
      await seed(tester, titles: ['a', 'a'], missing: ['/gone/x.flac']);
      final target = await seedPlaylist(tester, h, 'Target', [], now: 2);
      await openRowModal(tester);
      await tester.tap(modalAction('add-to-playlist'));
      await settleDb(tester);
      await tester.tap(inPicker('Target'));
      await tester.pumpAndSettle();
      await tester.tap(pickerAdd);
      await settleDb(tester);

      final copied = await storedPaths(tester, h, target);
      expect(copied, hasLength(3));
      expect(copied.last, '/gone/x.flac');
    });

    testWidgets(
      'both exports go through the save picker under the queue name',
      (tester) async {
        await seed(tester);
        for (final id in ['export-m3u', 'export-relative']) {
          await openRowModal(tester);
          await openAdvanced(tester);
          if (id == 'export-relative') {
            await tester.tap(
              find.descendant(
                of: modalAction('export-m3u'),
                matching: find.byTooltip('Export with relative paths'),
              ),
            );
            await settleModal(tester);
          } else {
            await tapModalAction(tester, id);
          }
          await settleDb(tester);
        }
        expect(suggested, hasLength(2));
        expect(suggested.every((n) => n.contains('Oct 22')), isTrue);
      },
    );
  });
}
