import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/playback_controls.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

final _songs = [
  for (final name in ['a', 'b', 'c']) Track.fromPath('/music/$name.mp3'),
];

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {required int start}) async {
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
    );
    addTearDown(container.dispose);
    await container
        .read(playerServiceProvider.notifier)
        .openTracks(_songs, start: start);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: PlaybackControls()),
        ),
      ),
    );
  }

  bool enabled(WidgetTester tester, String tooltip) =>
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip(tooltip),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed !=
      null;

  void setEndless(bool on) => container
      .read(settingsProvider.notifier)
      .setPlayback(PlaybackPrefs(infiniteQueue: on));

  testWidgets('next on the last track follows the endless queue setting', (
    tester,
  ) async {
    await pump(tester, start: 2);
    expect(enabled(tester, 'Next'), isFalse);

    setEndless(true);
    await tester.pump();
    expect(enabled(tester, 'Next'), isTrue);

    setEndless(false);
    await tester.pump();
    expect(enabled(tester, 'Next'), isFalse);
  });

  testWidgets('previous on the first track follows the setting too', (
    tester,
  ) async {
    await pump(tester, start: 0);
    expect(enabled(tester, 'Previous'), isFalse);

    setEndless(true);
    await tester.pump();
    expect(enabled(tester, 'Previous'), isTrue);
  });
}
