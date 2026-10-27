import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/playback_fade.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/sleep_timer.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_header.dart';
import 'package:kanaru/features/player/now_playing/now_playing_title_bar.dart';
import 'package:kanaru/features/player/repeat/repeat_button.dart';
import 'package:kanaru/features/player/volume_button.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart' hide RepeatMode;

import '../../core/player/fake_audio_backend.dart';
import '../../core/player/manual_fade_clock.dart';

/// Marks what the header wrapped in its drag exclusion.
class _Excluded extends StatelessWidget {
  const _Excluded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

void main() {
  late ProviderContainer container;
  late ValueNotifier<bool> floating;
  var closed = 0;

  /// Width of the window buttons and their right padding in the shell.
  const windowButtons = 152.0 + 16;

  /// The header in a row like the shell's title bar builds it: the header
  /// first, then room for the window buttons.
  Future<void> pump(
    WidgetTester tester, {
    double width = 1280,
    bool windowButtons = false,
    double textScale = 1,
    Widget? modeButton,
    bool exclude = false,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        // A clock moved by hand, so a running timer leaves no real one.
        playbackFadeClockProvider.overrideWithValue(ManualFadeClock().clock),
      ],
    );
    addTearDown(container.dispose);
    floating = ValueNotifier<bool>(false);
    addTearDown(floating.dispose);
    closed = 0;
    await container.read(playerServiceProvider.notifier).openTracks([
      Track.fromPath('/music/a.mp3'),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: Row(
                children: [
                  Expanded(
                    child: NowPlayingHeader(
                      onClose: () => closed++,
                      excludeFromDrag: exclude
                          ? (button) => _Excluded(child: button)
                          : noDragExclusion,
                      floatingOpen: floating,
                      hasWindowButtons: windowButtons,
                      modeButton: modeButton,
                    ),
                  ),
                  if (windowButtons)
                    const SizedBox(
                      width: 168,
                      child: Placeholder(strokeWidth: 0),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double centerX(WidgetTester tester, String tooltip) =>
      tester.getCenter(find.byTooltip(tooltip)).dx;

  testWidgets('has its buttons in order and no queue button', (tester) async {
    await pump(tester);

    final order = [
      'Close Now Playing',
      'Add to favorites',
      'Add to playlist',
      'Shuffle',
      'Stop after the last song',
      'Sleep timer',
      'Mute',
    ].map((tooltip) => centerX(tester, tooltip)).toList();
    expect(order, orderedEquals([...order]..sort()));
    expect(find.byTooltip('Show now playing list'), findsNothing);
    expect(tester.getSize(find.byType(NowPlayingHeader)).height, 64);
  });

  testWidgets('the close button closes', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Close Now Playing'));
    expect(closed, 1);
  });

  testWidgets('the mode slot sits right of close, before the song actions', (
    tester,
  ) async {
    await pump(
      tester,
      modeButton: const SizedBox(key: Key('mode'), width: 48, height: 48),
    );

    final mode = tester.getCenter(find.byKey(const Key('mode'))).dx;
    expect(mode, greaterThan(centerX(tester, 'Close Now Playing')));
    expect(mode, lessThan(centerX(tester, 'Add to favorites')));
  });

  testWidgets('a gap, not a line, separates the left groups', (tester) async {
    await pump(tester);
    expect(find.byType(VerticalDivider), findsNothing);
    final gap =
        centerX(tester, 'Add to favorites') -
        centerX(tester, 'Close Now Playing');
    // Two buttons' width plus the gap.
    expect(gap, 48 + 16);
  });

  testWidgets('the right separator shows only with window buttons', (
    tester,
  ) async {
    await pump(tester, windowButtons: true);
    final line = find.byType(VerticalDivider);
    expect(line, findsOneWidget);
    expect(
      tester.getCenter(line).dx,
      greaterThan(tester.getRect(find.byType(VolumeButton)).right),
    );

    await pump(tester);
    expect(find.byType(VerticalDivider), findsNothing);
  });

  testWidgets('shuffle and repeat change the player', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Shuffle'));
    await tester.pump();
    expect(container.read(playerServiceProvider).queue.shuffled, isTrue);

    await tester.tap(find.byType(RepeatButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repeat the whole queue'));
    await tester.pumpAndSettle();
    expect(container.read(playerServiceProvider).queue.repeat, RepeatMode.all);
  });

  testWidgets('wraps its two groups in the drag exclusion', (tester) async {
    await pump(tester, exclude: true);

    expect(find.byType(_Excluded), findsNWidgets(2));
    // Everything that can be pressed is inside one of them.
    for (final tooltip in [
      'Close Now Playing',
      'Add to favorites',
      'Shuffle',
      'Sleep timer',
      'Mute',
    ]) {
      expect(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(_Excluded),
        ),
        findsOneWidget,
        reason: tooltip,
      );
    }
  });

  testWidgets('the volume popup opens below the button and sets floatingOpen', (
    tester,
  ) async {
    await pump(tester);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(10, 700));
    addTearDown(gesture.removePointer);
    expect(floating.value, isFalse);

    await gesture.moveTo(tester.getCenter(find.byType(VolumeButton)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(floating.value, isTrue);
    expect(
      tester.getRect(find.byType(Slider)).top,
      greaterThanOrEqualTo(tester.getRect(find.byType(VolumeButton)).bottom),
    );

    await gesture.moveTo(const Offset(10, 700));
    await tester.pump(const Duration(milliseconds: 400));
    expect(floating.value, isFalse);
  });

  testWidgets('the sleep menu opens downward and sets floatingOpen', (
    tester,
  ) async {
    await pump(tester);
    final button = tester.getRect(find.byTooltip('Sleep timer'));

    await tester.tap(find.byTooltip('Sleep timer'));
    await tester.pumpAndSettle();

    expect(floating.value, isTrue);
    final menu = tester.getRect(find.text('15 minutes'));
    expect(menu.top, greaterThanOrEqualTo(button.bottom));

    await tester.tap(find.text('15 minutes'));
    await tester.pumpAndSettle();
    expect(floating.value, isFalse);
  });

  testWidgets('the repeat menu sets floatingOpen while it is open', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byType(RepeatButton));
    await tester.pumpAndSettle();
    expect(floating.value, isTrue);

    await tester.tap(find.text('Repeat the current song'));
    await tester.pumpAndSettle();
    expect(floating.value, isFalse);
  });

  testWidgets('floatingOpen is cleared when the header leaves the tree', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Sleep timer'));
    await tester.pumpAndSettle();
    expect(floating.value, isTrue);

    await tester.pumpWidget(const SizedBox());

    expect(floating.value, isFalse);
  });

  testWidgets('the sleep label shows with room and drops without', (
    tester,
  ) async {
    await pump(tester);
    container.read(sleepTimerProvider.notifier).startMinutes(30);
    await tester.pump();
    expect(find.text('30:00'), findsOneWidget);

    // The right group is left with less than its buttons and the label.
    await pump(tester, width: 430);
    container.read(sleepTimerProvider.notifier).startMinutes(30);
    await tester.pump();
    expect(find.text('30:00'), findsNothing);
    expect(find.byTooltip('Sleep timer: 30:00 left'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.5]) {
    testWidgets('fits 720 px beside the window buttons at text scale $scale', (
      tester,
    ) async {
      await pump(tester, width: 720, windowButtons: true, textScale: scale);
      container.read(sleepTimerProvider.notifier).startMinutes(719);
      await tester.pump();

      expect(tester.takeException(), isNull);
      final header = tester.getRect(find.byType(NowPlayingHeader));
      expect(header.right, 720 - windowButtons);
      expect(
        tester.getRect(find.byType(VolumeButton)).right,
        lessThanOrEqualTo(header.right),
      );
      expect(
        tester.getRect(find.byTooltip('Add to playlist')).right,
        lessThan(tester.getRect(find.byTooltip('Shuffle')).left),
      );
    });
  }
}
