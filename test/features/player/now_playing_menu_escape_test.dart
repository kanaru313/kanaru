import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/embedded_lyrics_reader.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_controller.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/source/lyrics_source_button.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_overlay.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/fake_lyrics_readers.dart';
import '../../core/player/fake_audio_backend.dart';
import 'fake_translation_controller.dart';

const _sung = Track(uri: '/m/sung.flac', title: 'Sung', artist: 'A');

void main() {
  late ProviderContainer container;

  /// Opens the real Now Playing overlay in a window of [size].
  Future<void> pumpOverlay(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        embeddedLyricsReaderProvider.overrideWithValue(
          FakeEmbeddedLyricsReader(),
        ),
        lrcSidecarReaderProvider.overrideWithValue(
          FakeLrcSidecarReader()
            ..byPath['/m/sung.flac'] = '[00:00.00]First words',
        ),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(
            translation: TranslationPrefs(
              noticeAcknowledged: {LyricsTranslationService.google},
            ),
          ),
        ),
        lyricsTranslationProvider.overrideWith2(
          (_) =>
              FakeTranslationController(TranslationOff(fakeTranslationInfo())),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerServiceProvider.notifier).openTracks([_sung]);
    container.read(nowPlayingOpenProvider.notifier).open();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NowPlayingOverlay(behind: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> escape(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  final sourceMenu = find.text('Automatic');
  final translationMenu = find.text('Show translation');

  for (final (name, size) in [
    ('wide', const Size(1280, 800)),
    ('narrow', const Size(600, 900)),
  ]) {
    group('Escape with a mouse-opened menu, $name layout', () {
      testWidgets('closes the source menu and keeps Now Playing open', (
        tester,
      ) async {
        await pumpOverlay(tester, size);
        await tester.tap(find.byType(LyricsSourceButton));
        await tester.pumpAndSettle();
        expect(sourceMenu, findsOneWidget);

        await escape(tester);

        expect(sourceMenu, findsNothing);
        expect(container.read(nowPlayingOpenProvider), isTrue);
      });

      testWidgets('closes the translation menu and keeps Now Playing open', (
        tester,
      ) async {
        await pumpOverlay(tester, size);
        await tester.tap(find.byTooltip('Lyrics translation'));
        await tester.pumpAndSettle();
        expect(translationMenu, findsOneWidget);

        await escape(tester);

        expect(translationMenu, findsNothing);
        expect(container.read(nowPlayingOpenProvider), isTrue);
      });
    });
  }
}
