import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/embedded_lyrics_reader.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/lyrics_line.dart';
import 'package:kanaru/features/player/lyrics/lyrics_view.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_banner.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_placeholder.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/fake_lyrics_readers.dart';
import '../../core/lyrics_translation/fake_plugin_runner.dart';
import '../../core/player/fake_audio_backend.dart';
import 'fake_translation_controller.dart';

final _testPlugin = testTranslatePlugin;
const _synced = Track(uri: '/m/synced.flac', title: 'Synced');
const _plain = Track(uri: '/m/plain.flac', title: 'Plain');

TranslationReady _ready({
  TranslationServiceId? service,
  List<String?> lines = const ['Dòng một', 'Dòng hai'],
}) => TranslationReady(
  fakeTranslationInfo(),
  service ?? _testPlugin,
  'ja',
  lines,
  false,
);

void main() {
  late ProviderContainer container;
  late FakeTranslationController fake;

  Future<void> pump(
    WidgetTester tester,
    LyricsTranslationState state, {
    Track track = _synced,
    TranslationPrefs? settings,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    fake = FakeTranslationController(state);
    container = ProviderContainer(
      overrides: [
        fakeTranslationOverride(fake),
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        embeddedLyricsReaderProvider.overrideWithValue(
          FakeEmbeddedLyricsReader(),
        ),
        lrcSidecarReaderProvider.overrideWithValue(
          FakeLrcSidecarReader()
            ..byPath['/m/synced.flac'] =
                '[00:00.00]First words\n[00:05.00]More words'
            ..byPath['/m/plain.flac'] = 'First words\nMore words',
        ),
        ...translatePluginOverrides(),
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            translation:
                settings ??
                TranslationPrefs(
                  show: true,
                  service: _testPlugin,
                  noticeAcknowledged: {_testPlugin},
                ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerServiceProvider.notifier).openTracks([track]);
    await tester.pumpWidget(translationApp(container, const LyricsView()));
    // A loading state pulses forever: step instead of settling.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('ready: translations under the lines and no credit', (
    tester,
  ) async {
    await pump(tester, _ready());
    expect(find.text('First words'), findsOneWidget);
    expect(find.text('Dòng một'), findsOneWidget);
    expect(find.text('Dòng hai'), findsOneWidget);
    expect(find.textContaining('Translated by'), findsNothing);
  });

  testWidgets('plain lyrics: replace shows the translation as the main line', (
    tester,
  ) async {
    await pump(
      tester,
      _ready(),
      track: _plain,
      settings: TranslationPrefs(
        show: true,
        display: LyricsTranslationDisplay.replace,
        service: _testPlugin,
        noticeAcknowledged: {_testPlugin},
      ),
    );
    final big = tester.widget<Text>(find.text('Dòng một'));
    expect(find.text('First words'), findsOneWidget);
    expect(
      tester.getSize(find.text('Dòng một')).height,
      greaterThan(tester.getSize(find.text('First words')).height),
    );
    expect(big.data, 'Dòng một');
  });

  testWidgets('loading: a bar under each non-blank line, pulsing', (
    tester,
  ) async {
    await pump(tester, TranslationLoading(fakeTranslationInfo(), _testPlugin));
    expect(find.byType(LyricsTranslationPlaceholder), findsNWidgets(2));
    expect(tester.hasRunningAnimations, isTrue);
    // The pulse stops once the translation is there.
    fake.emit(_ready());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LyricsTranslationPlaceholder), findsNothing);
    expect(find.text('Dòng một'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('loading with reduced motion: still bars, nothing running', (
    tester,
  ) async {
    await pump(
      tester,
      TranslationLoading(fakeTranslationInfo(), _testPlugin),
      reduceMotion: true,
    );
    expect(find.byType(LyricsTranslationPlaceholder), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('quota failure: reason and Retry', (tester) async {
    await pump(
      tester,
      TranslationFailed(
        fakeTranslationInfo(),
        _testPlugin,
        TranslationFailureKind.quotaExceeded,
      ),
    );
    expect(find.text("The service's quota is used up."), findsOneWidget);
    // The lyrics stay under the banner.
    expect(find.text('First words'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(fake.retryCalls, 1);
    expect(find.textContaining('Use '), findsNothing);
  });

  testWidgets('key failure: points to Settings, no Retry', (tester) async {
    await pump(
      tester,
      TranslationFailed(
        fakeTranslationInfo(),
        _testPlugin,
        TranslationFailureKind.badKey,
      ),
    );
    expect(
      find.textContaining('Settings › Playback › Translation'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    expect(find.textContaining('Use '), findsNothing);
  });

  testWidgets('too long: no Retry', (tester) async {
    await pump(
      tester,
      TranslationFailed(
        fakeTranslationInfo(),
        _testPlugin,
        TranslationFailureKind.tooLong,
      ),
    );
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('same language: no translation lines and no note', (
    tester,
  ) async {
    await pump(
      tester,
      TranslationSameLanguage(fakeTranslationInfo(), _testPlugin),
    );
    expect(find.text('Lyrics are already in English'), findsNothing);
    expect(find.byType(LyricsTranslationPlaceholder), findsNothing);
    expect(find.textContaining('Translated by'), findsNothing);
  });

  testWidgets('off: no banner, no credit, no extra text', (tester) async {
    await pump(tester, TranslationOff(fakeTranslationInfo()));
    expect(find.text('First words'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(
      find.descendant(
        of: find.byType(LyricsLine),
        matching: find.byType(Column),
      ),
      findsNothing,
    );
  });

  testWidgets('an Arabic target sets the translation right to left', (
    tester,
  ) async {
    await pump(
      tester,
      TranslationReady(
        fakeTranslationInfo(songOverride: 'ar'),
        _testPlugin,
        'en',
        const ['مرحبا', 'وداعا'],
        false,
      ),
    );
    expect(
      tester.widget<Text>(find.text('مرحبا')).textDirection,
      TextDirection.rtl,
    );
    expect(tester.widget<Text>(find.text('First words')).textDirection, isNull);
  });

  testWidgets('the banner sits above plain lyrics, not over the first line', (
    tester,
  ) async {
    await pump(
      tester,
      TranslationFailed(
        fakeTranslationInfo(),
        _testPlugin,
        TranslationFailureKind.network,
      ),
      track: _plain,
    );
    final banner = tester.getRect(find.byType(LyricsTranslationBanner));
    final first = tester.getRect(find.text('First words'));
    expect(first.top, greaterThanOrEqualTo(banner.bottom));
  });
}
