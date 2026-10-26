import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/playback_fade.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/sleep_timer.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_header.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_title_bar.dart';
import 'package:kanaru/features/player/player_bar.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/features/player/sleep_timer/sleep_timer_button.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/fake_audio_backend.dart';
import '../../../core/player/manual_fade_clock.dart';

void main() {
  late ProviderContainer container;
  late ManualFadeClock time;

  SleepTimerState state() => container.read(sleepTimerProvider);

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    time = ManualFadeClock();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        playbackFadeClockProvider.overrideWithValue(time.clock),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KanaruApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
    await container.read(playerServiceProvider.notifier).openTracks([
      Track.fromPath('/music/a.mp3'),
      Track.fromPath('/music/b.mp3'),
    ]);
    await tester.pumpAndSettle();
  }

  final button = find.descendant(
    of: find.byType(PlayerBar),
    matching: find.byType(SleepTimerButton),
  );

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(
      find.descendant(of: button, matching: find.byType(IconButton)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  const startOptions = [
    '15 minutes',
    '30 minutes',
    '45 minutes',
    '60 minutes',
    '90 minutes',
    'Custom…',
    'End of track',
    'End of album',
    'End of queue',
  ];
  const controls = [
    'Add 5 minutes',
    'Remove 5 minutes',
    'Pause counting',
    'Cancel timer',
  ];

  testWidgets('the menu of an idle timer offers the presets and the modes', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byTooltip('Sleep timer'), findsOneWidget);
    await openMenu(tester);
    for (final text in startOptions) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    for (final text in controls) {
      expect(find.text(text), findsNothing, reason: text);
    }
  });

  testWidgets('a preset starts the minutes mode and the label counts down', (
    tester,
  ) async {
    await pumpApp(tester);
    await openMenu(tester);
    await choose(tester, '30 minutes');

    expect(state().mode, SleepTimerMode.minutes);
    expect(state().remaining, const Duration(minutes: 30));
    expect(find.text('30:00'), findsOneWidget);
    expect(find.byTooltip('Sleep timer: 30:00 left'), findsOneWidget);

    await time.advance(const Duration(seconds: 61));
    await tester.pump();
    expect(find.text('28:59'), findsOneWidget);
  });

  testWidgets('the running timer adds, removes, holds and cancels', (
    tester,
  ) async {
    await pumpApp(tester);
    await openMenu(tester);
    await choose(tester, '15 minutes');

    await openMenu(tester);
    expect(find.text('15:00 left'), findsOneWidget);
    for (final text in [...controls, ...startOptions]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    await choose(tester, 'Add 5 minutes');
    expect(state().remaining, const Duration(minutes: 20));

    await openMenu(tester);
    await choose(tester, 'Remove 5 minutes');
    expect(state().remaining, const Duration(minutes: 15));

    await openMenu(tester);
    await choose(tester, 'Pause counting');
    expect(state().countingPaused, isTrue);

    await openMenu(tester);
    expect(find.text('15:00 left (paused)'), findsOneWidget);
    expect(find.text('Pause counting'), findsNothing);
    await choose(tester, 'Resume counting');
    expect(state().countingPaused, isFalse);

    await openMenu(tester);
    await choose(tester, 'Cancel timer');
    expect(state().active, isFalse);
    expect(find.byTooltip('Sleep timer'), findsOneWidget);
  });

  testWidgets('removing is disabled when 5 minutes or less are left', (
    tester,
  ) async {
    await pumpApp(tester);
    container.read(sleepTimerProvider.notifier).startMinutes(5);
    await tester.pump();
    await openMenu(tester);
    final item = tester.widget<MenuItemButton>(
      find.ancestor(
        of: find.text('Remove 5 minutes'),
        matching: find.byType(MenuItemButton),
      ),
    );
    expect(item.onPressed, isNull);
  });

  testWidgets('a track mode shows its label and no minute controls', (
    tester,
  ) async {
    await pumpApp(tester);
    await openMenu(tester);
    await choose(tester, 'End of track');
    expect(state().mode, SleepTimerMode.endOfTrack);
    expect(find.text('Track'), findsOneWidget);

    await openMenu(tester);
    expect(find.text('End of track'), findsNWidgets(2));
    expect(find.text('Cancel timer'), findsOneWidget);
    for (final text in [
      'Add 5 minutes',
      'Remove 5 minutes',
      'Pause counting',
    ]) {
      expect(find.text(text), findsNothing, reason: text);
    }
    await choose(tester, 'End of queue');
    expect(state().mode, SleepTimerMode.endOfQueue);
    expect(find.text('Queue'), findsOneWidget);
  });

  group('custom minutes', () {
    Future<void> openDialog(WidgetTester tester) async {
      await openMenu(tester);
      await choose(tester, 'Custom…');
    }

    const message = 'Enter a whole number from 1 to 720';

    for (final text in ['0', '721', 'abc', '']) {
      testWidgets('rejects "$text"', (tester) async {
        await pumpApp(tester);
        await openDialog(tester);
        await tester.enterText(find.byType(TextFormField), text);
        await tester.tap(find.text('Start'));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(state().active, isFalse);
      });
    }

    for (final (text, minutes) in [('1', 1), ('720', 720), (' 45 ', 45)]) {
      testWidgets('accepts "$text"', (tester) async {
        await pumpApp(tester);
        await openDialog(tester);
        await tester.enterText(find.byType(TextFormField), text);
        await tester.tap(find.text('Start'));
        await tester.pumpAndSettle();
        expect(find.text(message), findsNothing);
        expect(state().mode, SleepTimerMode.minutes);
        expect(state().remaining, Duration(minutes: minutes));
      });
    }

    testWidgets('Enter submits and Cancel starts nothing', (tester) async {
      await pumpApp(tester);
      await openDialog(tester);
      await tester.enterText(find.byType(TextFormField), '20');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(state().remaining, const Duration(minutes: 20));

      await openMenu(tester);
      await choose(tester, 'Custom…');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(state().remaining, const Duration(minutes: 20));
    });
  });

  testWidgets('the label is dropped where the bar is tight', (tester) async {
    await pumpApp(tester, size: const Size(1000, 700));
    container.read(sleepTimerProvider.notifier).startMinutes(10);
    await tester.pump();
    expect(button, findsOneWidget);
    expect(find.text('10:00'), findsNothing);
    expect(find.byTooltip('Sleep timer: 10:00 left'), findsOneWidget);
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
        await pumpApp(tester, size: Size(width, 700));
        container.read(sleepTimerProvider.notifier).startMinutes(719);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(button, shown ? findsOneWidget : findsNothing);
      },
    );
  }

  testWidgets('the Now Playing header has the button and fits at 720 px', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(720, 700));
    container.read(nowPlayingOpenProvider.notifier).open();
    container.read(sleepTimerProvider.notifier).startMinutes(719);
    await tester.pumpAndSettle();

    final inHeader = find.descendant(
      of: find.byType(NowPlayingHeader),
      matching: find.byType(SleepTimerButton),
    );
    expect(inHeader, findsOneWidget);
    expect(find.byTooltip('Sleep timer: 11:59:00 left'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu header follows the countdown while it is open', (
    tester,
  ) async {
    await pumpApp(tester);
    container.read(sleepTimerProvider.notifier).startMinutes(10);
    await tester.pump();
    await openMenu(tester);
    expect(find.text('10:00 left'), findsOneWidget);
    await time.advance(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('9:57 left'), findsOneWidget);
  });

  testWidgets('the header at 720 px has room for the label', (tester) async {
    await pumpApp(tester, size: const Size(720, 700));
    container.read(nowPlayingOpenProvider.notifier).open();
    container.read(sleepTimerProvider.notifier).startMinutes(30);
    await tester.pumpAndSettle();
    expect(find.text('30:00'), findsOneWidget);
    expect(find.byTooltip('Sleep timer: 30:00 left'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final width in [400.0, 719.0]) {
    testWidgets('the compact bar at $width px keeps the icon, no label', (
      tester,
    ) async {
      await pumpApp(tester, size: Size(width, 700));
      container.read(sleepTimerProvider.notifier).startMinutes(719);
      await tester.pump();
      expect(button, findsOneWidget);
      expect(find.text('11:59:00'), findsNothing);
      await openMenu(tester);
      expect(find.text('Cancel timer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the header reports its sleep menu open, then closed', (
    tester,
  ) async {
    final events = <bool>[];
    final floating = ValueNotifier<bool>(false);
    floating.addListener(() => events.add(floating.value));
    addTearDown(floating.dispose);
    await pumpApp(tester, size: const Size(1280, 800));
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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

    await tester.tap(find.text('15 minutes'));
    await tester.pumpAndSettle();
    expect(events, [true, false]);
  });
}
