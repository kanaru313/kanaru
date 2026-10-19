import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

void main() {
  late WidgetTester tester;

  Future<ProviderContainer> pumpApp(WidgetTester t) async {
    tester = t;
    t.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
        child: const KanaruApp(),
      ),
    );
    await t.pumpAndSettle();
    return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
  }

  ThemeMode themeMode() =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

  testWidgets('theme changes apply without a restart', (t) async {
    final container = await pumpApp(t);
    expect(themeMode(), ThemeMode.system);

    container.read(settingsProvider.notifier).setTheme(ThemePreference.dark);
    await t.pumpAndSettle();
    expect(themeMode(), ThemeMode.dark);

    container.read(settingsProvider.notifier).setTheme(ThemePreference.light);
    await t.pumpAndSettle();
    expect(themeMode(), ThemeMode.light);
  });

  testWidgets('language changes apply without a restart', (t) async {
    final container = await pumpApp(t);
    expect(find.text('Songs'), findsWidgets);

    container.read(settingsProvider.notifier).setLanguage('vi');
    await t.pumpAndSettle();
    expect(find.text('Bài hát'), findsWidgets);
    expect(find.text('Songs'), findsNothing);

    container.read(settingsProvider.notifier).setLanguage(null);
    await t.pumpAndSettle();
    expect(find.text('Songs'), findsWidgets);
  });

  testWidgets('a language without a translation follows the system', (t) async {
    final container = await pumpApp(t);

    container.read(settingsProvider.notifier).setLanguage('fr');
    await t.pumpAndSettle();
    expect(find.text('Songs'), findsWidgets);
    expect(find.text('Bài hát'), findsNothing);
  });
}
