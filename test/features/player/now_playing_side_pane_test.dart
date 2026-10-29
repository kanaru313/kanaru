import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanaru/features/player/now_playing/now_playing_side_tab.dart';
import 'package:kanaru/features/player/now_playing/now_playing_view_mode.dart';
import 'package:kanaru/features/player/queue/queue_panel.dart';
import 'package:material_ui/material_ui.dart';

import 'now_playing_split_harness.dart';

void main() {
  final h = SplitHarness();
  Future<void> pump(WidgetTester tester, {bool lyrics = true}) =>
      h.pump(tester, lyrics: lyrics);

  final lyricsTab = find.widgetWithText(Tab, 'Lyrics');
  final queueTab = find.widgetWithText(Tab, 'Now playing');
  final tabBar = find.byType(TabBar);

  group('tabs', () {
    testWidgets('with lyrics there are Lyrics and Queue tabs', (tester) async {
      await pump(tester);
      expect(lyricsTab, findsOneWidget);
      expect(queueTab, findsOneWidget);
      // Starts on Lyrics: the queue is not built.
      expect(find.text('LYRICS'), findsOneWidget);
      expect(find.byType(QueuePanel), findsNothing);
    });

    testWidgets('without lyrics there are still both tabs, Lyrics shows the '
        'empty slot', (tester) async {
      await pump(tester, lyrics: false);
      expect(lyricsTab, findsOneWidget);
      expect(queueTab, findsOneWidget);
      expect(tester.widget<TabBar>(tabBar).controller!.index, 0);
      expect(find.text('LYRICS'), findsNothing);
      expect(find.byType(QueuePanel), findsNothing);
    });

    testWidgets('switching tabs unmounts the other body', (tester) async {
      await pump(tester);

      await tester.tap(queueTab);
      await tester.pumpAndSettle();
      expect(find.byType(QueuePanel), findsOneWidget);
      expect(find.text('LYRICS'), findsNothing);

      await tester.tap(lyricsTab);
      await tester.pumpAndSettle();
      expect(find.byType(QueuePanel), findsNothing);
      expect(find.text('LYRICS'), findsOneWidget);
    });

    testWidgets('the Queue tab has the queue actions, Lyrics none', (
      tester,
    ) async {
      await pump(tester);
      for (final tooltip in ['Filter in this page', 'More actions']) {
        expect(find.byTooltip(tooltip), findsNothing, reason: tooltip);
      }

      await tester.tap(queueTab);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Filter in this page'), findsOneWidget);
      expect(find.byTooltip('More actions'), findsOneWidget);
    });

    testWidgets('the tab bar keeps its place on both tabs', (tester) async {
      await pump(tester);
      final onLyrics = tester.getRect(tabBar);

      await tester.tap(queueTab);
      await tester.pumpAndSettle();

      expect(tester.getRect(tabBar), onLyrics);
    });

    testWidgets('keyboard focus on a tab survives switching the tab', (
      tester,
    ) async {
      await pump(tester);
      // Walk the focus to the Queue tab.
      var steps = 0;
      bool onQueueTab() {
        final context = FocusManager.instance.primaryFocus?.context;
        if (context is! Element) return false;
        if (context.findAncestorWidgetOfExactType<TabBar>() == null) {
          return false;
        }
        return find
            .descendant(
              of: find.byElementPredicate((e) => e == context),
              matching: find.text('Now playing'),
            )
            .evaluate()
            .isNotEmpty;
      }

      while (!onQueueTab() && steps++ < 60) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(onQueueTab(), isTrue);
      final focused = FocusManager.instance.primaryFocus;

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byType(QueuePanel), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(onQueueTab(), isTrue);
    });

    for (final startOnQueue in [false, true]) {
      testWidgets('the chosen tab stays across lyrics changes '
          '(${startOnQueue ? 'queue' : 'lyrics'} chosen)', (tester) async {
        await pump(tester);
        if (startOnQueue) {
          await tester.tap(queueTab);
          await tester.pumpAndSettle();
        }

        for (var cycle = 0; cycle < 2; cycle++) {
          h.hasLyrics.value = false;
          await tester.pumpAndSettle();
          expect(lyricsTab, findsOneWidget);
          expect(queueTab, findsOneWidget);
          expect(
            find.byType(QueuePanel),
            startOnQueue ? findsOneWidget : findsNothing,
          );

          h.hasLyrics.value = true;
          await tester.pumpAndSettle();
          expect(
            tester.widget<TabBar>(tabBar).controller!.index,
            startOnQueue ? 1 : 0,
          );
          expect(
            find.byType(QueuePanel),
            startOnQueue ? findsOneWidget : findsNothing,
          );
          expect(
            find.text('LYRICS'),
            startOnQueue ? findsNothing : findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('mounted without lyrics, lyrics arriving show them in the '
        'Lyrics tab', (tester) async {
      await pump(tester, lyrics: false);
      h.hasLyrics.value = true;
      await tester.pumpAndSettle();

      expect(find.text('LYRICS'), findsOneWidget);
      expect(find.byType(QueuePanel), findsNothing);
    });

    testWidgets('losing the lyrics while on their tab stays on Lyrics', (
      tester,
    ) async {
      await pump(tester);
      h.hasLyrics.value = false;
      await tester.pumpAndSettle();

      final bar = tester.widget<TabBar>(tabBar);
      expect(bar.controller!.length, 2);
      expect(bar.controller!.index, 0);
      expect(find.byType(QueuePanel), findsNothing);
    });
  });

  group('the tab kept for the app session', () {
    testWidgets('the first opening shows Lyrics', (tester) async {
      await pump(tester);
      expect(
        h.container.read(nowPlayingSideTabProvider),
        NowPlayingSideTab.lyrics,
      );
      expect(find.text('LYRICS'), findsOneWidget);
    });

    testWidgets('a new app session starts on Lyrics again', (tester) async {
      await pump(tester);
      await tester.tap(queueTab);
      await tester.pumpAndSettle();
      expect(
        h.container.read(nowPlayingSideTabProvider),
        NowPlayingSideTab.queue,
      );

      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      expect(fresh.read(nowPlayingSideTabProvider), NowPlayingSideTab.lyrics);
    });

    testWidgets('closing and reopening Now Playing keeps the Queue tab', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(queueTab);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await h.repump(tester);

      expect(find.byType(QueuePanel), findsOneWidget);
      expect(tester.widget<TabBar>(tabBar).controller!.index, 1);
    });

    testWidgets('leaving Split and coming back keeps the Queue tab', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(queueTab);
      await tester.pumpAndSettle();

      final modes = h.container.read(nowPlayingViewModeProvider.notifier);
      modes.choose(NowPlayingViewMode.coverOnly);
      await tester.pumpAndSettle();
      expect(find.byType(QueuePanel), findsNothing);
      modes.choose(NowPlayingViewMode.split);
      await tester.pumpAndSettle();

      expect(find.byType(QueuePanel), findsOneWidget);
      expect(tester.widget<TabBar>(tabBar).controller!.index, 1);
    });

    testWidgets('a narrow resize and back keeps the Queue tab', (tester) async {
      await pump(tester);
      await tester.tap(queueTab);
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();
      expect(queueTab, findsNothing);
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();

      expect(find.byType(QueuePanel), findsOneWidget);
      expect(tester.widget<TabBar>(tabBar).controller!.index, 1);
    });
  });
}
