import 'dart:async';
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

  test('library sort setters save, and the same value does not', () async {
    final container = containerFor();
    final notifier = container.read(settingsProvider.notifier);
    var notified = 0;
    container.listen(settingsProvider, (_, _) => notified++);

    notifier.setSongSort(const SortChoice(SongSortField.year));
    notifier.setAlbumSort(const SortChoice(AlbumSortField.artist));
    notifier.setArtistSort(
      const SortChoice(ArtistSortField.songCount, descending: true),
    );
    notifier.setAlbumsView(AlbumsView.list);
    await notifier.flush();
    expect(notified, 4);
    expect(SettingsFile(path).load(), container.read(settingsProvider));
    expect(stored()['albumsView'], 'list');

    File(path).deleteSync();
    notifier.setSongSort(const SortChoice(SongSortField.year));
    notifier.setAlbumsView(AlbumsView.list);
    await notifier.flush();
    expect(notified, 4);
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
  group('under a slow file', () {
    late _GatedFile gated;

    ProviderContainer slowContainer() {
      gated = _GatedFile(path);
      final container = ProviderContainer(
        overrides: [settingsFileProvider.overrideWithValue(gated)],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> tick() => Future<void>.delayed(Duration.zero);

    test('a burst of changes makes at most two writes and the last state '
        'is what ends up saved', () async {
      final container = slowContainer();
      final notifier = container.read(settingsProvider.notifier);

      notifier.setTheme(ThemePreference.dark);
      for (var i = 0; i < 4; i++) {
        notifier.setTheme(ThemePreference.light);
        notifier.setTheme(ThemePreference.dark);
      }
      notifier.setLanguage('vi');
      await tick();
      expect(gated.started, hasLength(1), reason: 'one write in flight');

      gated.finishNext();
      await tick();
      await tick();
      gated.finishNext();
      await notifier.flush();

      expect(gated.started, hasLength(2));
      expect(gated.started.last, container.read(settingsProvider));
      expect(gated.saved.last, container.read(settingsProvider));
    });

    test('flush waits for the write in flight and the pending one', () async {
      final container = slowContainer();
      final notifier = container.read(settingsProvider.notifier);

      notifier.setTheme(ThemePreference.dark);
      await tick();
      notifier.setTheme(ThemePreference.light);
      var flushed = false;
      final flushing = notifier.flush().then((_) => flushed = true);

      gated.finishNext();
      await tick();
      await tick();
      expect(flushed, isFalse, reason: 'the pending write is not done');
      expect(gated.started, hasLength(2));

      gated.finishNext();
      await flushing;
      expect(gated.saved.last.theme, ThemePreference.light);
    });

    test('flush with nothing to write completes at once', () async {
      final notifier = slowContainer().read(settingsProvider.notifier);
      await notifier.flush();
    });

    test(
      'a failed first write followed by a good one clears the warning',
      () async {
        final container = slowContainer();
        final notifier = container.read(settingsProvider.notifier);

        notifier.setTheme(ThemePreference.dark);
        await tick();
        notifier.setTheme(ThemePreference.light);
        gated.finishNext(succeed: false);
        await tick();
        await tick();
        gated.finishNext();
        await notifier.flush();

        expect(container.read(settingsSaveFailedProvider), isFalse);
      },
    );

    test('a good first write does not hide a failed later one', () async {
      final container = slowContainer();
      final notifier = container.read(settingsProvider.notifier);

      notifier.setTheme(ThemePreference.dark);
      await tick();
      notifier.setTheme(ThemePreference.light);
      gated.finishNext();
      await tick();
      await tick();
      gated.finishNext(succeed: false);
      await notifier.flush();

      expect(container.read(settingsSaveFailedProvider), isTrue);
    });
  });
}

/// A settings file whose writes finish only when the test says so.
class _GatedFile extends SettingsFile {
  _GatedFile(super.path);

  final started = <AppSettings>[];
  final saved = <AppSettings>[];
  final _gates = <Completer<bool>>[];
  var _finished = 0;

  @override
  Future<bool> save(AppSettings settings) {
    started.add(settings);
    final gate = Completer<bool>();
    _gates.add(gate);
    return gate.future.then((ok) {
      if (ok) saved.add(settings);
      return ok;
    });
  }

  void finishNext({bool succeed = true}) =>
      _gates[_finished++].complete(succeed);
}

bool _isRoot() => Process.runSync('id', ['-u']).stdout.toString().trim() == '0';
