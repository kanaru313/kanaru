import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/applied_appearance_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../core/player/fake_audio_backend.dart';

/// Smallest step the tests pump to cross the delay.
const _tick = Duration(milliseconds: 1);

void main() {
  late ProviderContainer container;

  Future<void> pumpApp(WidgetTester tester, {AppSettings? initial}) async {
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        if (initial != null) initialSettingsProvider.overrideWithValue(initial),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KanaruApp()),
    );
    await tester.pumpAndSettle();
  }

  MaterialApp app(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp));

  SettingsNotifier settings() => container.read(settingsProvider.notifier);

  testWidgets('applies the saved theme at startup without a pause', (
    tester,
  ) async {
    await pumpApp(
      tester,
      initial: const AppSettings(theme: ThemePreference.dark),
    );

    expect(app(tester).themeMode, ThemeMode.dark);
  });

  testWidgets('a theme change reaches the app after the pause', (tester) async {
    await pumpApp(tester);

    settings().setTheme(ThemePreference.dark);
    expect(container.read(settingsProvider).theme, ThemePreference.dark);
    await tester.pump(appearanceApplyDelay - _tick);
    expect(app(tester).themeMode, ThemeMode.system);

    await tester.pump(_tick);
    expect(app(tester).themeMode, ThemeMode.dark);
  });

  testWidgets('a burst of theme changes applies only the last one', (
    tester,
  ) async {
    await pumpApp(tester);
    final modes = <ThemeMode>[];

    for (final theme in [
      ThemePreference.dark,
      ThemePreference.light,
      ThemePreference.dark,
      ThemePreference.light,
    ]) {
      settings().setTheme(theme);
      await tester.pump(appearanceApplyDelay * 2 ~/ 3);
      modes.add(app(tester).themeMode!);
    }
    expect(modes, everyElement(ThemeMode.system));
    expect(container.read(settingsProvider).theme, ThemePreference.light);

    await tester.pump(appearanceApplyDelay ~/ 3);
    expect(app(tester).themeMode, ThemeMode.light);
  });

  testWidgets('a language change reaches the app after the pause', (
    tester,
  ) async {
    await pumpApp(tester);

    settings().setLanguage('vi');
    settings().setLanguage('en');
    settings().setLanguage('vi');
    expect(container.read(settingsProvider).languageCode, 'vi');
    await tester.pump(appearanceApplyDelay - _tick);
    expect(app(tester).locale, isNot(const Locale('vi')));

    await tester.pump(_tick);
    expect(app(tester).locale, const Locale('vi'));
  });

  testWidgets('settings that are not appearance do not wait', (tester) async {
    await pumpApp(tester);

    settings().setTitleBar(TitleBarPreference.none);

    expect(container.read(settingsProvider).titleBar, TitleBarPreference.none);
  });

  testWidgets('leaves no timer pending when the app goes away', (tester) async {
    await pumpApp(tester);

    settings().setTheme(ThemePreference.dark);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
