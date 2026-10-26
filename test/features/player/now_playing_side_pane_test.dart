import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

    testWidgets('without lyrics there is the Queue tab only', (tester) async {
      await pump(tester, lyrics: false);
      expect(lyricsTab, findsNothing);
      expect(queueTab, findsOneWidget);
      expect(find.byType(QueuePanel), findsOneWidget);
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

    testWidgets('the Queue tab has the four queue actions, Lyrics none', (
      tester,
    ) async {
      await pump(tester);
      for (final tooltip in [
        'Filter in this page',
        'Jump to current song',
        'Save queue as playlist',
        'Clear queue',
      ]) {
        expect(find.byTooltip(tooltip), findsNothing, reason: tooltip);
      }

      await tester.tap(queueTab);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Filter in this page'), findsOneWidget);
      expect(find.byTooltip('Jump to current song'), findsOneWidget);
      expect(find.byTooltip('Save queue as playlist'), findsOneWidget);
      expect(find.byTooltip('Clear queue'), findsOneWidget);
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
      testWidgets('lyrics going away and coming back never asserts '
          '(${startOnQueue ? 'queue' : 'lyrics'} chosen)', (tester) async {
        await pump(tester);
        if (startOnQueue) {
          await tester.tap(queueTab);
          await tester.pumpAndSettle();
        }

        h.hasLyrics.value = false;
        await tester.pumpAndSettle();
        expect(lyricsTab, findsNothing);
        expect(find.byType(QueuePanel), findsOneWidget);

        h.hasLyrics.value = true;
        await tester.pumpAndSettle();
        // Lyrics coming back start on their tab again.
        expect(lyricsTab, findsOneWidget);
        expect(find.text('LYRICS'), findsOneWidget);

        h.hasLyrics.value = false;
        await tester.pumpAndSettle();
        h.hasLyrics.value = true;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('losing the lyrics while on their tab lands on the queue', (
      tester,
    ) async {
      await pump(tester);
      h.hasLyrics.value = false;
      await tester.pumpAndSettle();

      final bar = tester.widget<TabBar>(tabBar);
      expect(bar.controller!.length, 1);
      expect(bar.controller!.index, 0);
      expect(find.byType(QueuePanel), findsOneWidget);
    });
  });
}
