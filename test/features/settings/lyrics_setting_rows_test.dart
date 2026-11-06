import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_source_names.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/lyrics_setting_rows.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../core/lyrics/online/lookup_test_harness.dart';

void main() {
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: LyricsSettingRows()),
        ),
      ),
    );
  }

  final row = find.ancestor(
    of: find.text('Prefer embedded lyrics'),
    matching: find.byType(SettingRow),
  );
  final toggle = find.descendant(of: row, matching: find.byType(Switch));

  testWidgets('the prefer embedded lyrics switch is live', (tester) async {
    await pump(tester);
    expect(tester.widget<SettingRow>(row).comingSoon, isFalse);
    expect(
      find.descendant(of: row, matching: find.text('Coming soon')),
      findsNothing,
    );
    expect(tester.widget<Switch>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pump();
    expect(
      container.read(settingsProvider).playback.preferEmbeddedLyrics,
      isTrue,
    );
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pump();
    expect(
      container.read(settingsProvider).playback.preferEmbeddedLyrics,
      isFalse,
    );
  });

  testWidgets('changing it keeps the other playback settings', (tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(settingsProvider.notifier)
        .setPlayback(const PlaybackPrefs(gapless: false, crossfadeSeconds: 6));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: LyricsSettingRows()),
        ),
      ),
    );
    await tester.tap(toggle);
    await tester.pump();
    final playback = container.read(settingsProvider).playback;
    expect(playback.preferEmbeddedLyrics, isTrue);
    expect(playback.gapless, isFalse);
    expect(playback.crossfadeSeconds, 6);
  });

  group('automatic online lookup switch', () {
    final autoRow = find.ancestor(
      of: find.text('Find lyrics online automatically'),
      matching: find.byType(SettingRow),
    );
    final autoSwitch = find.descendant(
      of: autoRow,
      matching: find.byType(Switch),
    );
    const noSourceHint =
        'No online lyrics source is on · Add a plugin in Lyrics sources';

    testWidgets('with no source on it is off, disabled and says why', (
      tester,
    ) async {
      final h = await createHarness(
        const [],
        autoFetch: true,
        autoConsent: true,
      );
      container = h.container;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(body: LyricsSettingRows()),
          ),
        ),
      );

      final toggle = tester.widget<Switch>(autoSwitch);
      expect(toggle.value, isFalse);
      expect(toggle.onChanged, isNull);
      expect(find.text(noSourceHint), findsOneWidget);
      // The stored choice is untouched.
      final stored = container.read(settingsProvider).onlineLyrics;
      expect((stored.autoFetch, stored.autoConsent), (true, true));
    });

    testWidgets('with a source on it works as before', (tester) async {
      await pump(
        tester,
        overrides: [
          lyricsSourcesLoadedProvider.overrideWithValue(true),
          lyricsProvidersProvider.overrideWithValue([
            LyricsProviderRegistration(FakeLyricsProvider()),
          ]),
        ],
      );

      expect(tester.widget<Switch>(autoSwitch).onChanged, isNotNull);
      expect(find.text(noSourceHint), findsNothing);
    });

    testWidgets('before the sources are read it is not disabled', (
      tester,
    ) async {
      await pump(
        tester,
        overrides: [
          lyricsSourcesLoadedProvider.overrideWithValue(false),
          lyricsProvidersProvider.overrideWithValue(const []),
        ],
      );

      expect(tester.widget<Switch>(autoSwitch).onChanged, isNotNull);
      expect(find.text(noSourceHint), findsNothing);
    });
  });
}
