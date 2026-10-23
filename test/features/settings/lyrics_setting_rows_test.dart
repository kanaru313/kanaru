import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/lyrics_setting_rows.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    container = ProviderContainer();
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
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pump();
    expect(
      container.read(settingsProvider).playback.preferEmbeddedLyrics,
      isFalse,
    );
    expect(tester.widget<Switch>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pump();
    expect(
      container.read(settingsProvider).playback.preferEmbeddedLyrics,
      isTrue,
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
    expect(playback.preferEmbeddedLyrics, isFalse);
    expect(playback.gapless, isFalse);
    expect(playback.crossfadeSeconds, 6);
  });
}
