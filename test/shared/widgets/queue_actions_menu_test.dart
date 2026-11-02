import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/songs/songs_list_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/library/browse_test_data.dart';
import '../../features/library/library_test_harness.dart';
import '../song_modal/song_modal_test_support.dart';

const _tracks = [TestTrack('a'), TestTrack('b'), TestTrack('c')];

void main() {
  List<String> queue(LibraryHarness h) => [
    for (final t in h.container.read(playerServiceProvider).queue.tracks)
      t.title,
  ];

  group('song modal opening', () {
    testWidgets(
      'a right click opens the song modal, not a popup at the pointer',
      (tester) async {
        final h = LibraryHarness();
        await openWithTracks(tester, h, _tracks, location: '/songs');

        await openSongModal(tester, find.text('b'));

        expect(find.text('Go to artist'), findsOneWidget);
        expect(find.byType(PopupMenuItem<Object?>), findsNothing);
        // A centered dialog, not anchored at the pointer.
        final window = tester.getSize(find.byType(MaterialApp).first);
        expect(
          tester.getCenter(modalAction('artist')).dx,
          closeTo(window.width / 2, window.width / 4),
        );
      },
    );

    testWidgets('a long press opens the song modal', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/songs');

      await tester.longPress(find.text('b'));
      await settleSongModal(tester);

      expect(find.text('Go to artist'), findsOneWidget);
      expect(find.byType(PopupMenuItem<Object?>), findsNothing);
    });
  });

  group('rows shown while the ids load', () {
    // The ids never arrive: only the first page of rows is on screen.
    LibraryHarness harness() => LibraryHarness(
      overrides: [songIdsProvider.overrideWith((ref) => const Stream.empty())],
    );

    testWidgets('a right click opens the menu and queues the song', (
      tester,
    ) async {
      final h = harness();
      await openWithTracks(tester, h, _tracks, location: '/songs');
      expect(find.text('b'), findsOneWidget);

      await tester.tap(find.text('b'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to queue'));
      await settleIo(tester, h);

      expect(queue(h), ['b']);
      expect(find.text('Playing: b'), findsOneWidget);
    });

    testWidgets('a long press opens the menu without playing the row', (
      tester,
    ) async {
      final h = harness();
      await openWithTracks(tester, h, _tracks, location: '/songs');

      await tester.longPress(find.text('b'));
      await tester.pumpAndSettle();

      expect(find.text('Play next'), findsOneWidget);
      expect(queue(h), isEmpty, reason: 'a long press is not a tap');
      expect(h.backend.calls.where((c) => c.startsWith('open(')), isEmpty);
    });
  });

  group('focus of a popup menu', () {
    /// A focusable row in a [QueueActionsRegion], and a button that opens
    /// the queue menu as a pointer would (no keyboard).
    Future<FocusNode> pumpRow(
      WidgetTester tester, {
      bool accessibleNavigation = false,
    }) async {
      final focus = FocusNode(debugLabel: 'row');
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(accessibleNavigation: accessibleNavigation),
            child: child!,
          ),
          home: Scaffold(
            body: Column(
              children: [
                const SizedBox(height: 100),
                QueueActionsRegion(
                  onAction: (_) {},
                  child: InkWell(
                    focusNode: focus,
                    onTap: () {},
                    child: const SizedBox(height: 48, child: Text('row')),
                  ),
                ),
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () =>
                        showQueueActionsMenu(context, const Offset(10, 200)),
                    child: const Text('pointer open'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return focus;
    }

    /// The text of the menu row that has the primary focus, or null.
    String? focusedRow() {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) return null;
      final item = context
          .findAncestorWidgetOfExactType<PopupMenuItem<QueueAction>>();
      if (item == null) return null;
      return switch (item.value) {
        QueueAction.playNext => 'Play next',
        QueueAction.addToQueue => 'Add to queue',
        QueueAction.addToPlaylist => 'Add to playlist',
        null => null,
      };
    }

    testWidgets('the Menu key focuses the first row of the menu', (
      tester,
    ) async {
      final focus = await pumpRow(tester);
      focus.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();

      expect(find.text('Play next'), findsOneWidget);
      expect(focusedRow(), 'Play next');

      // Arrow keys move on from there.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(focusedRow(), 'Add to queue');
    });

    testWidgets('a pointer open focuses no row', (tester) async {
      await pumpRow(tester);

      await tester.tap(find.text('pointer open'));
      await tester.pumpAndSettle();

      expect(find.text('Play next'), findsOneWidget);
      expect(focusedRow(), isNull);
    });

    testWidgets('a right click focuses no row', (tester) async {
      await pumpRow(tester);

      await tester.tap(find.text('row'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.text('Play next'), findsOneWidget);
      expect(focusedRow(), isNull);
    });

    testWidgets(
      'with a screen reader on a pointer open focuses the first row',
      (tester) async {
        await pumpRow(tester, accessibleNavigation: true);

        await tester.tap(find.text('pointer open'));
        await tester.pumpAndSettle();

        expect(focusedRow(), 'Play next');
      },
    );

    testWidgets('Esc right after the Menu key leaves focus on the row', (
      tester,
    ) async {
      final focus = await pumpRow(tester);
      focus.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Play next'), findsNothing);
      expect(focus.hasPrimaryFocus, isTrue);
    });
  });
}
