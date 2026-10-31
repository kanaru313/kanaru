import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/player/now_playing/now_playing_header.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_title_bar.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/features/player/sleep_timer/sleep_timer_button.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/fake_audio_backend.dart';
import 'sleep_timer_harness.dart';

void main() {
  final h = SleepTimerHarness();

  Future<void> openMenu(WidgetTester tester) => h.open(tester);
  final button = h.barButton;

  testWidgets('the button opens the dialog on the setup tabs when idle', (
    tester,
  ) async {
    await h.pump(tester);
    expect(find.byTooltip('Sleep timer'), findsOneWidget);
    await openMenu(tester);
    expect(find.text('Sleep after'), findsOneWidget);
    for (final text in ['Minutes', 'Tracks', 'End of…', 'Start']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.text('Turn off'), findsNothing);
  });

  testWidgets('the button opens the running view while a timer runs', (
    tester,
  ) async {
    await h.pump(tester);
    h.timer.startMinutes(30);
    await tester.pump();
    expect(find.text('30:00'), findsOneWidget);
    expect(find.byTooltip('Sleep timer: Sleeping in 30:00'), findsOneWidget);

    await openMenu(tester);
    expect(find.text('Turn off'), findsOneWidget);
    expect(find.text('Sleeping in 30:00'), findsOneWidget);

    await h.time.advance(const Duration(seconds: 61));
    await tester.pump();
    expect(find.text('28:59'), findsWidgets);
  });

  testWidgets('a tracks timer shows its label and its tooltip', (tester) async {
    await h.pump(tester);
    h.timer.startTracks(3);
    await tester.pump();
    expect(find.text('3 tracks'), findsOneWidget);
    expect(
      find.byTooltip('Sleep timer: Pauses after 3 more tracks'),
      findsOneWidget,
    );
    h.timer.startTracks(1);
    await tester.pump();
    expect(find.text('1 track'), findsOneWidget);
  });

  testWidgets('a track mode shows its label beside the button', (tester) async {
    await h.pump(tester);
    h.timer.startEndOfTrack();
    await tester.pump();
    expect(find.text('Track'), findsOneWidget);
    h.timer.startEndOfQueue();
    await tester.pump();
    expect(find.text('Queue'), findsOneWidget);
  });

  testWidgets('the label is dropped where the bar is tight', (tester) async {
    await h.pump(tester, size: const Size(1000, 700));
    h.timer.startMinutes(10);
    await tester.pump();
    expect(button, findsOneWidget);
    expect(find.text('10:00'), findsNothing);
    expect(find.byTooltip('Sleep timer: Sleeping in 10:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (width, shown) in [
    (720.0, false),
    (800.0, false),
    (900.0, true),
    (1100.0, true),
    (1280.0, true),
  ]) {
    testWidgets(
      'the bar lays out at $width px with the timer on and ${shown ? 'shows' : 'omits'} the button',
      (tester) async {
        await h.pump(tester, size: Size(width, 700));
        h.timer.startMinutes(719);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(button, shown ? findsOneWidget : findsNothing);
      },
    );
  }

  testWidgets('the Now Playing header has the button and fits at 720 px', (
    tester,
  ) async {
    await h.pump(tester, size: const Size(720, 700));
    h.container.read(nowPlayingOpenProvider.notifier).open();
    h.timer.startMinutes(719);
    await tester.pumpAndSettle();

    final inHeader = find.descendant(
      of: find.byType(NowPlayingHeader),
      matching: find.byType(SleepTimerButton),
    );
    expect(inHeader, findsOneWidget);
    expect(find.byTooltip('Sleep timer: Sleeping in 11:59:00'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header at 720 px has room for the label', (tester) async {
    await h.pump(tester, size: const Size(720, 700));
    h.container.read(nowPlayingOpenProvider.notifier).open();
    h.timer.startMinutes(30);
    await tester.pumpAndSettle();
    expect(find.text('30:00'), findsOneWidget);
    expect(find.byTooltip('Sleep timer: Sleeping in 30:00'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final width in [400.0, 719.0]) {
    testWidgets('the compact bar at $width px keeps the icon, no label', (
      tester,
    ) async {
      await h.pump(tester, size: Size(width, 700));
      h.timer.startMinutes(719);
      await tester.pump();
      expect(button, findsOneWidget);
      expect(find.text('11:59:00'), findsNothing);
      await openMenu(tester);
      expect(find.text('Turn off'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the header reports its sleep dialog open, then closed', (
    tester,
  ) async {
    final events = <bool>[];
    final floating = ValueNotifier<bool>(false);
    floating.addListener(() => events.add(floating.value));
    addTearDown(floating.dispose);
    await h.pump(tester, size: const Size(1280, 800));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: NowPlayingHeader(
                onClose: () {},
                excludeFromDrag: noDragExclusion,
                floatingOpen: floating,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sleep timer'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(events, [true]);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(events, [true, false]);
  });

  testWidgets('onDialogChanged reports open, closed and a dispose while open', (
    tester,
  ) async {
    final events = <bool>[];
    final show = ValueNotifier<bool>(true);
    addTearDown(show.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: show,
              builder: (_, visible, _) => visible
                  ? SleepTimerButton(onDialogChanged: events.add)
                  : const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(events, [true]);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(events, [true, false]);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    show.value = false;
    await tester.pumpAndSettle();
    expect(events, [true, false, true, false]);
    expect(tester.takeException(), isNull);
  });
}
