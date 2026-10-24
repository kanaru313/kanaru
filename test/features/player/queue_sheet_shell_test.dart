import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/features/player/player_bar.dart';
import 'package:kanaru/features/player/queue/queue_panel.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

/// The queue sheet of the app shell next to the player bar.
void main() {
  late ProviderContainer container;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
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
      for (var i = 0; i < 4; i++)
        Track(uri: '/music/t$i.mp3', title: 't$i', artist: 'a$i'),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show now playing list'));
    await tester.pumpAndSettle();
  }

  testWidgets('the sheet ends where the player bar starts', (tester) async {
    await pumpApp(tester);

    expect(
      tester.getBottomLeft(find.byType(QueuePanel)).dy,
      tester.getTopLeft(find.byType(PlayerBar)).dy,
    );
  });

  testWidgets('the player bar stays clickable while the sheet is open', (
    tester,
  ) async {
    await pumpApp(tester);

    final bar = find.byType(PlayerBar);
    expect(
      find
          .descendant(of: bar, matching: find.byTooltip('Sleep timer'))
          .hitTestable(),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: bar, matching: find.byTooltip('Sleep timer')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QueuePanel), findsOneWidget);
    expect(find.text('End of track'), findsWidgets);
  });

  testWidgets('Esc closes the sheet after a bar menu was used', (tester) async {
    await pumpApp(tester);
    final sleep = find.descendant(
      of: find.byType(PlayerBar),
      matching: find.byTooltip('Sleep timer'),
    );

    // Open the sleep menu from the bar and close it again.
    await tester.tap(sleep);
    await tester.pumpAndSettle();
    expect(find.text('End of track'), findsWidgets);
    await tester.tap(sleep);
    await tester.pumpAndSettle();
    expect(find.byType(QueuePanel), findsOneWidget);

    // Focus is now on a bar control, outside the sheet.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(QueuePanel), findsNothing);
  });

  testWidgets('Now Playing opens without the sheet behind it', (tester) async {
    await pumpApp(tester);

    container.read(nowPlayingOpenProvider.notifier).open();
    await tester.pumpAndSettle();
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    container.read(nowPlayingOpenProvider.notifier).close();
    await tester.pumpAndSettle();

    expect(find.byType(NowPlayingScreen), findsNothing);
    expect(find.byType(QueuePanel), findsNothing);
  });

  testWidgets(
    'Esc with a mouse-opened bar menu closes the sheet and leaves the menu',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(PlayerBar),
          matching: find.byTooltip('Sleep timer'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('End of track'), findsWidgets);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(QueuePanel), findsNothing);
      // The menu holds no focus when opened by mouse: it stays until a click.
      expect(find.text('End of track'), findsWidgets);
    },
  );
}
