import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/playback_controls.dart';
import 'package:kanaru/features/player/repeat/repeat_button.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart' hide RepeatMode;

import '../../core/player/fake_audio_backend.dart';

void main() {
  Future<ProviderContainer> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  Future<void> queue(ProviderContainer c, WidgetTester tester) async {
    await c.read(playerServiceProvider.notifier).openTracks([
      const Track(uri: '/music/a.mp3', title: 'a'),
      const Track(uri: '/music/b.mp3', title: 'b'),
    ]);
    await tester.pumpAndSettle();
  }

  testWidgets('the shuffle button toggles shuffle', (tester) async {
    final c = await pump(tester, const ShuffleButton());
    await queue(c, tester);

    await tester.tap(find.byTooltip('Shuffle'));
    await tester.pumpAndSettle();
    expect(c.read(playerServiceProvider).queue.shuffled, isTrue);
  });

  testWidgets('the repeat button opens a menu that sets repeat', (
    tester,
  ) async {
    final c = await pump(tester, const RepeatButton());
    await queue(c, tester);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repeat the whole queue'));
    await tester.pumpAndSettle();
    expect(c.read(playerServiceProvider).queue.repeat, RepeatMode.all);
  });

  testWidgets('both are disabled while the queue is empty', (tester) async {
    await pump(
      tester,
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [ShuffleButton(), RepeatButton()],
      ),
    );

    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    expect(buttons, hasLength(2));
    expect(buttons.every((b) => b.onPressed == null), isTrue);
  });

  testWidgets('transport only shows previous, play and next', (tester) async {
    await pump(tester, const PlaybackControls(transportOnly: true));

    expect(find.byType(IconButton), findsNWidgets(3));
    expect(find.byTooltip('Previous'), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.byTooltip('Next'), findsOneWidget);
  });

  testWidgets('the full controls keep all five buttons', (tester) async {
    await pump(tester, const PlaybackControls());

    expect(find.byType(IconButton), findsNWidgets(5));
  });

  test('compact and transport only exclude each other', () {
    expect(
      () => PlaybackControls(compact: true, transportOnly: true),
      throwsAssertionError,
    );
  });
}
