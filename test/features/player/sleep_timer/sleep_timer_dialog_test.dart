import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/sleep_timer.dart';
import 'package:kanaru/features/player/now_playing/now_playing_header.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/sleep_timer/sleep_timer_button.dart';
import 'package:kanaru/features/player/sleep_timer/sleep_timer_draft.dart';
import 'package:material_ui/material_ui.dart';

import 'sleep_timer_harness.dart';

void main() {
  final h = SleepTimerHarness();

  final start = find.widgetWithText(FilledButton, 'Start');
  final slider = find.descendant(
    of: dialogFinder,
    matching: find.byType(Slider),
  );

  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(
      find.descendant(of: dialogFinder, matching: find.text(text)),
    );
    await settle(tester);
  }

  FilledButton startButton(WidgetTester tester) =>
      tester.widget<FilledButton>(start);

  IconButton iconButton(WidgetTester tester, String tooltip) =>
      tester.widget<IconButton>(
        find.widgetWithIcon(
          IconButton,
          tooltip == '-' ? Icons.remove : Icons.add,
        ),
      );

  group('opening', () {
    testWidgets('the player bar button opens a 420 px dialog at the centre', (
      tester,
    ) async {
      await h.pump(tester);
      await h.open(tester);
      final rect = tester.getRect(dialogCard);
      expect(rect.width, 420);
      expect(rect.center.dx, closeTo(640, 1));
      expect(rect.center.dy, closeTo(400, 1));
    });

    testWidgets('the compact bar button opens it too', (tester) async {
      await h.pump(tester, size: const Size(500, 700));
      await h.open(tester);
      expect(find.text('Sleep after'), findsOneWidget);
      expect(tester.getRect(dialogCard).center.dx, closeTo(250, 1));
    });

    testWidgets('the header pill opens it and the dialog survives the screen', (
      tester,
    ) async {
      await h.pump(tester);
      h.container.read(nowPlayingOpenProvider.notifier).open();
      h.timer.startMinutes(20);
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NowPlayingHeader),
          matching: find.byType(SleepTimerButton),
        ),
      );
      await settle(tester);
      expect(find.text('Sleep timer'), findsWidgets);
      expect(find.text('Turn off'), findsOneWidget);

      // Closing Now Playing under the dialog does not break it.
      h.container.read(nowPlayingOpenProvider.notifier).close();
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap on the backdrop closes it', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      expect(dialogFinder, findsNothing);
    });

    testWidgets('Esc closes it and starts nothing', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(dialogFinder, findsNothing);
      expect(h.state.active, isFalse);
    });
  });

  group('focus', () {
    testWidgets('picking a tab with the keyboard keeps the focus on the tabs', (
      tester,
    ) async {
      await h.pump(tester);
      await h.open(tester);
      final field = find.descendant(
        of: dialogFinder,
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);

      // Shift+Tab walks back from the field to the tab strip.
      Future<void> shiftTab() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
      }

      // "-", then the End of…, Tracks segments.
      for (var i = 0; i < 3; i++) {
        await shiftTab();
      }
      // Enter picks the segment (the segment buttons ignore Space here).
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);

      expect(find.text('tracks'), findsOneWidget);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        focused
            .findAncestorWidgetOfExactType<
              SegmentedButton<SleepTimerSetupTab>
            >(),
        isNotNull,
      );
    });

    testWidgets('Esc returns the focus to a button the keyboard opened', (
      tester,
    ) async {
      await h.pump(tester);
      final icon = find.descendant(
        of: h.barButton,
        matching: find.byType(IconButton),
      );
      // The focus node of the button itself: the nearest one above its icon.
      Element context() => tester.element(
        find.descendant(of: icon, matching: find.byType(Icon)),
      );
      Focus.of(context()).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(dialogFinder, findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(dialogFinder, findsNothing);
      expect(Focus.of(context()).hasFocus, isTrue);
    });
  });

  group('setup', () {
    testWidgets('the tabs swap the body', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      expect(find.text('min'), findsOneWidget);
      expect(find.text('1h'), findsOneWidget);

      await tapText(tester, 'Tracks');
      expect(find.text('tracks'), findsOneWidget);
      expect(find.textContaining('Pauses after 3 tracks'), findsOneWidget);
      expect(find.text('1h'), findsNothing);

      await tapText(tester, 'End of…');
      expect(find.text('Album'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('- and + step 5 minutes and stop at 1 and 720', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await tester.tap(find.byTooltip('Add 5 minutes'));
      await tester.pump();
      expect(find.text('50'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '1');
      await tester.pump();
      expect(iconButton(tester, '-').onPressed, isNull);
      await tester.enterText(find.byType(TextField).last, '720');
      await tester.pump();
      expect(iconButton(tester, '+').onPressed, isNull);
      expect(iconButton(tester, '-').onPressed, isNotNull);
    });

    testWidgets('- and + step 1 track and stop at 1 and 20', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await tapText(tester, 'Tracks');
      await tester.tap(find.byTooltip('Add one track'));
      await tester.pump();
      expect(find.text('4'), findsWidgets);
      await tester.enterText(find.byType(TextField).last, '20');
      await tester.pump();
      expect(iconButton(tester, '+').onPressed, isNull);
      await tester.enterText(find.byType(TextField).last, '1');
      await tester.pump();
      expect(iconButton(tester, '-').onPressed, isNull);
    });

    testWidgets('the sliders step 5 minutes (5 to 180) and 1 track (1 to 20)', (
      tester,
    ) async {
      await h.pump(tester);
      await h.open(tester);
      var s = tester.widget<Slider>(slider);
      expect((s.min, s.max, s.divisions), (5, 180, 35));
      await tapText(tester, 'Tracks');
      s = tester.widget<Slider>(slider);
      expect((s.min, s.max, s.divisions), (1, 20, 19));
    });

    testWidgets('a chip selects but does not start', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await tapText(tester, '1h30');
      expect(h.state.active, isFalse);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '1h30'))
            .selected,
        isTrue,
      );
      expect(find.text('90'), findsOneWidget);
      expect(find.byTooltip('90 minutes'), findsOneWidget);
    });

    testWidgets('Enter on a focused chip selects it and does not start', (
      tester,
    ) async {
      await h.pump(tester);
      await h.open(tester);
      // Tab order: field, +, slider, then the first chip.
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(h.state.active, isFalse);
      expect(dialogFinder, findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '15m'))
            .selected,
        isTrue,
      );
    });

    testWidgets('Enter on the slider starts the timer', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      // Tab order: field, +, slider.
      for (var i = 0; i < 2; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      final minutes = tester.widget<Slider>(slider).value.round();
      expect(minutes, 50);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(h.state.mode, SleepTimerMode.minutes);
      expect(h.state.remaining, Duration(minutes: minutes));
      expect(dialogFinder, findsNothing);
    });

    testWidgets('the Stops at hint uses the locale time format', (
      tester,
    ) async {
      await h.pump(tester);
      await h.open(tester);
      final context = tester.element(dialogFinder);
      final at = DateTime.now().add(const Duration(minutes: 45));
      final expected = MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(at),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
      expect(find.text('Stops at $expected'), findsOneWidget);
    });

    testWidgets('Start runs the minutes timer and closes', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await tapText(tester, '1h');
      await tester.tap(start);
      await settle(tester);
      expect(h.state.mode, SleepTimerMode.minutes);
      expect(h.state.remaining, const Duration(minutes: 60));
      expect(dialogFinder, findsNothing);
    });

    testWidgets('Start runs the tracks timer', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await tapText(tester, 'Tracks');
      await tapText(tester, '5');
      await tester.tap(start);
      await settle(tester);
      expect(h.state.mode, SleepTimerMode.tracks);
      expect(h.state.tracksLeft, 5);
    });

    for (final (label, mode) in [
      ('Track', SleepTimerMode.endOfTrack),
      ('Album', SleepTimerMode.endOfAlbum),
      ('Queue', SleepTimerMode.endOfQueue),
    ]) {
      testWidgets('End of needs a row before Start, then runs $label', (
        tester,
      ) async {
        await h.pump(tester);
        await h.open(tester);
        await tapText(tester, 'End of…');
        expect(startButton(tester).onPressed, isNull);
        await tapText(tester, label);
        expect(startButton(tester).onPressed, isNotNull);
        expect(dialogFinder, findsOneWidget);
        await tester.tap(start);
        await settle(tester);
        expect(h.state.mode, mode);
        expect(dialogFinder, findsNothing);
      });
    }

    testWidgets('Cancel closes and leaves a running timer alone', (
      tester,
    ) async {
      await h.pump(tester);
      h.timer.startMinutes(25);
      await tester.pump();
      await h.open(tester);
      await tapText(tester, 'Change…');
      await tapText(tester, 'Cancel');
      expect(dialogFinder, findsNothing);
      expect(h.state.remaining, const Duration(minutes: 25));
    });

    testWidgets('Start replaces a running timer', (tester) async {
      await h.pump(tester);
      h.timer.startMinutes(25);
      await tester.pump();
      await h.open(tester);
      await tapText(tester, 'Change…');
      await tapText(tester, 'Tracks');
      await tester.tap(start);
      await settle(tester);
      expect(h.state.mode, SleepTimerMode.tracks);
    });
  });

  group('running', () {
    testWidgets('minutes: +5, -5 (off at 5 minutes), pause and resume', (
      tester,
    ) async {
      await h.pump(tester);
      h.timer.startMinutes(15);
      await tester.pump();
      await h.open(tester);
      expect(find.text('Sleeping in 15:00'), findsOneWidget);

      await tapText(tester, '+5 min');
      expect(h.state.remaining, const Duration(minutes: 20));
      await tapText(tester, '−5 min');
      expect(h.state.remaining, const Duration(minutes: 15));

      await tapText(tester, 'Pause counting');
      expect(h.state.countingPaused, isTrue);
      expect(find.text('Counting paused · 15:00 left'), findsOneWidget);
      expect(find.text('Counting paused'), findsOneWidget);
      await tapText(tester, 'Resume counting');
      expect(h.state.countingPaused, isFalse);

      h.timer.cancel();
      h.timer.startMinutes(5);
      await tester.pump();
    });

    testWidgets('minutes: -5 is off at 5 minutes', (tester) async {
      await h.pump(tester);
      h.timer.startMinutes(5);
      await tester.pump();
      await h.open(tester);
      final minus = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '−5 min'),
      );
      expect(minus.onPressed, isNull);
    });

    testWidgets('the countdown follows the clock', (tester) async {
      await h.pump(tester);
      h.timer.startMinutes(10);
      await tester.pump();
      await h.open(tester);
      await h.time.advance(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('Sleeping in 9:57'), findsOneWidget);
    });

    testWidgets('tracks: +1 and -1 within the limits', (tester) async {
      await h.pump(tester);
      h.timer.startTracks(2);
      await tester.pump();
      await h.open(tester);
      expect(find.text('Pauses after 2 more tracks'), findsOneWidget);
      expect(find.text('tracks left, this one included'), findsOneWidget);

      await tapText(tester, '−1 track');
      expect(h.state.tracksLeft, 1);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '−1 track'),
            )
            .onPressed,
        isNull,
      );
      await tapText(tester, '+1 track');
      expect(h.state.tracksLeft, 2);

      h.timer.startTracks(sleepTimerMaxTracks);
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '+1 track'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('an end mode shows its kind and caption', (tester) async {
      await h.pump(tester);
      h.timer.startEndOfAlbum();
      await tester.pump();
      await h.open(tester);
      expect(find.text('Pauses at the end of this album'), findsOneWidget);
      expect(find.text('Pauses there; the queue stays'), findsOneWidget);
      expect(find.text('Album'), findsWidgets);
    });

    testWidgets('Turn off cancels and closes', (tester) async {
      await h.pump(tester);
      h.timer.startMinutes(15);
      await tester.pump();
      await h.open(tester);
      await tester.tap(find.text('Turn off'));
      await settle(tester);
      expect(h.state.active, isFalse);
      expect(dialogFinder, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Change… shows the setup filled from the timer, Running goes back',
      (tester) async {
        await h.pump(tester);
        h.timer.startTracks(7);
        await tester.pump();
        await h.open(tester);
        await tapText(tester, 'Change…');
        expect(find.text('Sleep after'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .controller!
              .text,
          '7',
        );
        await tapText(tester, 'Running');
        expect(find.text('Turn off'), findsOneWidget);
      },
    );

    testWidgets('a timer that ends by itself closes the dialog', (
      tester,
    ) async {
      await h.pump(tester);
      h.timer.startMinutes(1);
      await tester.pump();
      await h.open(tester);
      await h.time.advance(const Duration(seconds: 61));
      await settle(tester);
      expect(h.state.active, isFalse);
      expect(dialogFinder, findsNothing);
    });
  });

  group('layout', () {
    testWidgets('a short window scrolls without overflow', (tester) async {
      await h.pump(tester, size: const Size(600, 360));
      await h.open(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);

      h.timer.startMinutes(719);
      await tester.pump();
      await h.open(tester);
      await tester.ensureVisible(find.text('Change…'));
      await tester.tap(find.text('Change…'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a narrow window fits the dialog', (tester) async {
      await h.pump(tester, size: const Size(360, 700));
      await h.open(tester);
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Tracks');
      await tapText(tester, 'End of…');
      expect(tester.takeException(), isNull);
    });
  });
}
