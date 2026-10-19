import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

void main() {
  late Directory root;
  late String path;

  setUp(() {
    root = Directory.systemTemp.createTempSync('kanaru_settings_');
    path = '${root.path}/settings.json';
  });

  tearDown(() => root.deleteSync(recursive: true));

  ProviderContainer containerFor({AppSettings initial = const AppSettings()}) {
    final container = ProviderContainer(
      overrides: [
        settingsFileProvider.overrideWithValue(SettingsFile(path)),
        initialSettingsProvider.overrideWithValue(initial),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Map<String, Object?> stored() =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

  test('starts from the initial settings', () {
    const initial = AppSettings(theme: ThemePreference.dark);

    expect(containerFor(initial: initial).read(settingsProvider), initial);
    expect(File(path).existsSync(), isFalse);
  });

  test('several changes end up on disk with the last value', () async {
    final container = containerFor();
    final notifier = container.read(settingsProvider.notifier);

    notifier.setTheme(ThemePreference.dark);
    notifier.setTheme(ThemePreference.light);
    notifier.setLanguage('vi');
    notifier.setTitleBar(TitleBarPreference.none);
    await notifier.flush();

    expect(stored(), containsPair('theme', 'light'));
    expect(stored(), containsPair('language', 'vi'));
    expect(stored(), containsPair('titleBar', 'none'));
    expect(SettingsFile(path).load(), container.read(settingsProvider));
  });

  test('language can go back to the system default', () async {
    final container = containerFor();
    final notifier = container.read(settingsProvider.notifier);

    notifier.setLanguage('vi');
    notifier.setLanguage(null);
    await notifier.flush();

    expect(container.read(settingsProvider).languageCode, isNull);
    expect(stored()['language'], isNull);
  });

  test('setting the same value again does not write', () async {
    final container = containerFor();
    final notifier = container.read(settingsProvider.notifier);
    var notified = 0;
    container.listen(settingsProvider, (_, _) => notified++);

    notifier.setTheme(ThemePreference.system);
    notifier.setTitleBar(TitleBarPreference.kanaru);
    notifier.setLanguage(null);
    await notifier.flush();

    expect(notified, 0);
    expect(File(path).existsSync(), isFalse);
  });

  test('several changes leave the file equal to the state', () async {
    final container = containerFor();
    final notifier = container.read(settingsProvider.notifier);

    notifier.setTheme(ThemePreference.dark);
    notifier.setTheme(ThemePreference.system);
    notifier.setLanguage('vi');
    await notifier.flush();

    final state = container.read(settingsProvider);
    expect(state, const AppSettings(languageCode: 'vi'));
    expect(SettingsFile(path).load(), state);
  });

  test('works without a file', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(settingsProvider.notifier);

    notifier.setTheme(ThemePreference.light);
    await notifier.flush();

    expect(
      container.read(settingsProvider),
      const AppSettings(theme: ThemePreference.light),
    );
  });

  test(
    'a failed save is reported until a later save works',
    () async {
      final blocked = Directory('${root.path}/blocked')..createSync();
      Process.runSync('chmod', ['555', blocked.path]);
      addTearDown(() => Process.runSync('chmod', ['755', blocked.path]));
      path = '${blocked.path}/sub/settings.json';
      final container = containerFor();
      final notifier = container.read(settingsProvider.notifier);
      expect(container.read(settingsSaveFailedProvider), isFalse);

      notifier.setTheme(ThemePreference.dark);
      await notifier.flush();
      expect(container.read(settingsSaveFailedProvider), isTrue);

      Process.runSync('chmod', ['755', blocked.path]);
      notifier.setTheme(ThemePreference.light);
      await notifier.flush();
      expect(container.read(settingsSaveFailedProvider), isFalse);
      expect(stored(), containsPair('theme', 'light'));
    },
    skip: Platform.isLinux && _isRoot()
        ? 'root ignores directory modes'
        : false,
  );
}

bool _isRoot() => Process.runSync('id', ['-u']).stdout.toString().trim() == '0';
