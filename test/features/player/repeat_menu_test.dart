import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/player_state.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/repeat/repeat_button.dart';
import 'package:kanaru/features/player/repeat/repeat_mode_icon.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart' hide RepeatMode;

import '../../core/player/fake_audio_backend.dart';

void main() {
  late ProviderContainer container;
  late FakeAudioBackend backend;

  PlayerService player() => container.read(playerServiceProvider.notifier);
  PlayerState state() => container.read(playerServiceProvider);

  Future<void> pump(WidgetTester tester, {bool withQueue = true}) async {
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
    );
    addTearDown(container.dispose);
    if (withQueue) {
      await player().openTracks([
        const Track(uri: '/music/a.mp3', title: 'a'),
        const Track(uri: '/music/b.mp3', title: 'b'),
      ]);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Center(child: RepeatButton())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(RepeatButton));
    await tester.pumpAndSettle();
  }

  Finder item(String label) => find.widgetWithText(MenuItemButton, label);

  bool highlighted(WidgetTester tester, String label) {
    final selected = find.ancestor(
      of: item(label),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.selected == true,
      ),
    );
    return selected.evaluate().isNotEmpty;
  }

  IconButton step(WidgetTester tester, String tooltip) =>
      tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      );

  testWidgets(
    'opens on tap with five labelled items and closes on a second tap',
    (tester) async {
      await pump(tester);
      await openMenu(tester);

      for (final label in [
        'Stop after the last song',
        'Repeat the current song',
        'Repeat 1 more time',
        'Repeat the whole queue',
        'Repeat the whole queue (shuffled)',
      ]) {
        expect(item(label), findsOneWidget, reason: label);
      }

      await tester.tap(find.byType(RepeatButton));
      await tester.pumpAndSettle();
      expect(item('Repeat the current song'), findsNothing);
    },
  );

  testWidgets('the highlight follows the mode', (tester) async {
    await pump(tester);
    const labels = {
      RepeatMode.off: 'Stop after the last song',
      RepeatMode.one: 'Repeat the current song',
      RepeatMode.all: 'Repeat the whole queue',
      RepeatMode.allShuffled: 'Repeat the whole queue (shuffled)',
    };
    for (final MapEntry(key: mode, value: label) in labels.entries) {
      await player().setRepeat(mode);
      await openMenu(tester);
      for (final other in labels.values) {
        expect(
          highlighted(tester, other),
          other == label,
          reason: '$mode $other',
        );
      }
      expect(highlighted(tester, 'Repeat 1 more time'), isFalse);
      await tester.tap(find.byType(RepeatButton));
      await tester.pumpAndSettle();
    }

    await player().setRepeatTimes(2);
    await openMenu(tester);
    expect(highlighted(tester, 'Repeat 2 more times'), isTrue);
    expect(highlighted(tester, 'Repeat the whole queue (shuffled)'), isFalse);
  });

  testWidgets('a mode item applies the mode and closes the menu', (
    tester,
  ) async {
    await pump(tester);
    await openMenu(tester);
    await tester.tap(item('Repeat the whole queue'));
    await tester.pumpAndSettle();

    expect(state().queue.repeat, RepeatMode.all);
    expect(item('Repeat the current song'), findsNothing);
  });

  testWidgets('plus raises the draft, the counted item arms with it', (
    tester,
  ) async {
    await pump(tester);
    await openMenu(tester);
    await tester.tap(find.byTooltip('One more time'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('One more time'));
    await tester.pumpAndSettle();

    expect(state().repeatTimes, 0);
    expect(item('Repeat 3 more times'), findsOneWidget);
    await tester.tap(item('Repeat 3 more times'));
    await tester.pumpAndSettle();

    expect(state().repeatTimes, 3);
    expect(item('Repeat the current song'), findsNothing);
  });

  testWidgets('minus and plus change the live count and keep the menu open', (
    tester,
  ) async {
    await pump(tester);
    await player().setRepeatTimes(3);
    await openMenu(tester);

    await tester.tap(find.byTooltip('One time fewer'));
    await tester.pumpAndSettle();
    expect(state().repeatTimes, 2);
    expect(item('Repeat 2 more times'), findsOneWidget);

    await tester.tap(find.byTooltip('One more time'));
    await tester.pumpAndSettle();
    expect(state().repeatTimes, 3);
    expect(item('Repeat the current song'), findsOneWidget);

    // The engine's loop event moves the live text while the menu is open.
    backend.emitLooped.add(state().queue.current!);
    await tester.pumpAndSettle();
    expect(item('Repeat 2 more times'), findsOneWidget);
  });

  testWidgets('minus stops at 1 and plus at the maximum', (tester) async {
    await pump(tester);
    await openMenu(tester);
    expect(step(tester, 'One time fewer').onPressed, isNull);
    expect(step(tester, 'One more time').onPressed, isNotNull);

    await tester.tap(find.byType(RepeatButton));
    await tester.pumpAndSettle();
    await player().setRepeatTimes(maxRepeatTimes);
    await openMenu(tester);
    expect(step(tester, 'One more time').onPressed, isNull);
    expect(step(tester, 'One time fewer').onPressed, isNotNull);
  });

  testWidgets('the counted item is disabled while playback is stopped', (
    tester,
  ) async {
    await pump(tester);
    await player().stop();
    await openMenu(tester);

    expect(
      tester.widget<MenuItemButton>(item('Repeat 1 more time')).onPressed,
      isNull,
    );
    expect(step(tester, 'One more time').onPressed, isNull);
    expect(step(tester, 'One time fewer').onPressed, isNull);
  });

  testWidgets('the button icon and tooltip show the active mode', (
    tester,
  ) async {
    await pump(tester);
    IconButton button() => tester.widget<IconButton>(find.byType(IconButton));
    Finder icon(IconData data) => find.descendant(
      of: find.byType(IconButton),
      matching: find.byIcon(data),
    );

    expect(find.byTooltip('Stop after the last song'), findsOneWidget);
    expect(button().isSelected, isFalse);
    expect(icon(Icons.repeat_rounded), findsOneWidget);

    await player().setRepeat(RepeatMode.one);
    await tester.pump();
    expect(find.byTooltip('Repeat the current song'), findsOneWidget);
    expect(icon(Icons.repeat_one_rounded), findsOneWidget);
    expect(button().isSelected, isTrue);

    await player().setRepeat(RepeatMode.all);
    await tester.pump();
    expect(find.byTooltip('Repeat the whole queue'), findsOneWidget);
    expect(icon(Icons.repeat_rounded), findsOneWidget);
    expect(icon(Icons.shuffle_rounded), findsNothing);

    await player().setRepeat(RepeatMode.allShuffled);
    await tester.pump();
    expect(find.byTooltip('Repeat the whole queue (shuffled)'), findsOneWidget);
    expect(icon(Icons.repeat_rounded), findsOneWidget);
    expect(icon(Icons.shuffle_rounded), findsOneWidget);

    await player().setRepeatTimes(4);
    await tester.pump();
    expect(find.byTooltip('Repeat 4 more times'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(IconButton),
        matching: find.byType(RepeatCountIcon),
      ),
      findsOneWidget,
    );
    expect(button().isSelected, isTrue);
  });

  testWidgets('is disabled while the queue is empty', (tester) async {
    await pump(tester, withQueue: false);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
  });

  testWidgets('menu rows carry the icon of their mode', (tester) async {
    await pump(tester);
    await player().setRepeat(RepeatMode.off);
    await openMenu(tester);

    Finder rowIcon(String label, Finder icon) =>
        find.descendant(of: item(label), matching: icon);
    expect(
      rowIcon(
        'Stop after the last song',
        find.byIcon(Icons.playlist_play_rounded),
      ),
      findsOneWidget,
    );
    expect(
      rowIcon('Repeat the current song', find.byIcon(Icons.repeat_one_rounded)),
      findsOneWidget,
    );
    expect(
      rowIcon('Repeat 1 more time', find.byType(RepeatCountIcon)),
      findsOneWidget,
    );
    expect(
      rowIcon('Repeat the whole queue', find.byIcon(Icons.repeat_rounded)),
      findsOneWidget,
    );
    final shuffled = rowIcon(
      'Repeat the whole queue (shuffled)',
      find.byIcon(Icons.shuffle_rounded),
    );
    expect(shuffled, findsOneWidget);
  });

  testWidgets('cycling repeat skips the counted item', (tester) async {
    await pump(tester);
    await player().setRepeatTimes(3);
    await player().cycleRepeat();
    expect(state().repeatTimes, 0);

    final seen = <RepeatMode>[state().queue.repeat];
    for (var i = 0; i < 4; i++) {
      await player().cycleRepeat();
      expect(state().repeatTimes, 0);
      seen.add(state().queue.repeat);
    }
    expect(seen.toSet(), RepeatMode.values.toSet());
  });
}
