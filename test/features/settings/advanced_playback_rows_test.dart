import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/playback_setting_rows.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(child: PlaybackSettingRows()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(SettingRow));

  PlaybackPrefs prefs() => container.read(settingsProvider).playback;

  Future<void> pick(WidgetTester tester, String title, String option) async {
    expect(tester.widget<SettingRow>(row(title)).comingSoon, isFalse);
    await tester.tap(
      find.descendant(of: row(title), matching: find.byType(TextField)),
    );
    await tester.pumpAndSettle();
    // Every dropdown keeps its menu items; only the open one can be hit.
    await tester.tap(
      find.widgetWithText(MenuItemButton, option).hitTestable().first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the listen threshold rows save the picked values', (
    tester,
  ) async {
    await pump(tester);

    await pick(tester, 'A listen counts after', '2 min');
    expect(prefs().listenThresholdMinutes, 2);

    await pick(tester, 'A listen counts after (share of the song)', '75%');
    expect(prefs().listenThresholdPercent, 75);
  });

  testWidgets('the endless queue switch is live', (tester) async {
    await pump(tester);
    expect(tester.widget<SettingRow>(row('Endless queue')).comingSoon, isFalse);
    await tester.tap(
      find.descendant(of: row('Endless queue'), matching: find.byType(Switch)),
    );
    await tester.pump();
    expect(prefs().infiniteQueue, isTrue);
  });

  testWidgets('the fade rows save the picked lengths', (tester) async {
    await pump(tester);

    await pick(tester, 'Fade in on play', '300 ms');
    expect(prefs().fadeOnPlayMs, 300);

    await pick(tester, 'Fade out on pause', '500 ms');
    expect(prefs().fadeOnPauseMs, 500);
  });
}
