import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lrclib_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
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

  test('library options are saved, and onboarding is marked once', () async {
    final container = containerFor();
    final notifier = container.read(settingsProvider.notifier);

    notifier.setRescanOnStartup(false);
    notifier.markLibraryOnboarded();
    notifier.markLibraryOnboarded();
    await notifier.flush();

    final settings = container.read(settingsProvider);
    expect(settings.rescanOnStartup, isFalse);
    expect(settings.libraryOnboarded, isTrue);
    expect(stored()['rescanOnStartup'], false);
    expect(stored()['libraryOnboarded'], true);
  });

  test('enabling selects the service, acknowledges it and shows', () async {
    final container = containerFor();
    final notifier = container.read(settingsProvider.notifier);
    var changes = 0;
    container.listen(settingsProvider, (_, _) => changes++);

    notifier.enableTranslation(LyricsTranslationService.deepl);
    await notifier.flush();

    expect(changes, 1);
    final translation = container.read(settingsProvider).translation;
    expect(translation.show, isTrue);
    expect(translation.service, LyricsTranslationService.deepl);
    expect(translation.noticeAcknowledged, {LyricsTranslationService.deepl});
    final json = stored()['lyricsTranslation']! as Map;
    expect(json['show'], true);
    expect(json['service'], 'deepl');
    expect(json['noticeAcknowledged'], ['deepl']);
  });

  test('acknowledging only records the notice', () async {
    final container = containerFor();
    final notifier = container.read(settingsProvider.notifier);

    notifier.acknowledgeTranslationNotice(LyricsTranslationService.google);

    final translation = container.read(settingsProvider).translation;
    expect(translation.show, isFalse);
    expect(translation.needsNotice, isFalse);
  });

  test('translation never turns on for an unacknowledged service', () async {
    final container = containerFor();
    final notifier = container.read(settingsProvider.notifier);

    notifier.setTranslation(const TranslationPrefs(show: true));
    expect(container.read(settingsProvider).translation.show, isFalse);

    notifier.toggleLyricsTranslation();
    expect(container.read(settingsProvider).translation.show, isFalse);

    notifier.acknowledgeTranslationNotice(LyricsTranslationService.deepl);
    notifier.setTranslation(
      container
          .read(settingsProvider)
          .translation
          .copyWith(show: true, service: LyricsTranslationService.google),
    );
    expect(container.read(settingsProvider).translation.show, isFalse);
  });

  test('setTranslation cannot add an acknowledgment', () {
    final container = containerFor();
    final notifier = container.read(settingsProvider.notifier);

    notifier.setTranslation(
      const TranslationPrefs(
        show: true,
        noticeAcknowledged: {LyricsTranslationService.google},
      ),
    );

    final translation = container.read(settingsProvider).translation;
    expect(translation.noticeAcknowledged, isEmpty);
    expect(translation.show, isFalse);
  });

  test('translation prefs and the toggle are saved', () async {
    final container = containerFor();
    final notifier = container.read(settingsProvider.notifier);

    notifier.acknowledgeTranslationNotice(LyricsTranslationService.google);
    notifier.setTranslation(
      container.read(settingsProvider).translation.withTargetLanguage('vi'),
    );
    notifier.toggleLyricsTranslation();
    await notifier.flush();

    expect(container.read(settingsProvider).translation.show, isTrue);
    expect((stored()['lyricsTranslation']! as Map)['targetLanguage'], 'vi');
    expect((stored()['lyricsTranslation']! as Map)['show'], true);
  });

  test('the listen history switch is saved', () async {
    final container = containerFor();
    final notifier = container.read(settingsProvider.notifier);

    notifier.setRecordListenHistory(false);
    await notifier.flush();

    expect(container.read(settingsProvider).recordListenHistory, isFalse);
    expect(stored()['recordListenHistory'], false);
  });

  test(
    'the animations switch is saved and survives a language change',
    () async {
      final container = containerFor();
      final notifier = container.read(settingsProvider.notifier);

      notifier.setAnimations(false);
      notifier.setLanguage('vi');
      await notifier.flush();

      expect(container.read(settingsProvider).animations, isFalse);
      expect(stored()['animations'], false);
      expect(stored()['language'], 'vi');
    },
  );

  test('each group setter is saved and a language change keeps them', () async {
    final container = containerFor();
    final notifier = container.read(settingsProvider.notifier);
    const scan = LibraryScanPrefs(minFileSizeKb: 500);
    const playback = PlaybackPrefs(gapless: false);
    final display = DisplayPrefs(sidebarTabs: {SidebarTab.songs});

    notifier.setLibraryScan(scan);
    notifier.setPlayback(playback);
    notifier.setDisplay(display);
    notifier.setLanguage('vi');
    notifier.setAnimations(false);
    await notifier.flush();

    final settings = container.read(settingsProvider);
    expect(settings.libraryScan, scan);
    expect(settings.playback, playback);
    expect(settings.display, display);
    expect(settings.animations, isFalse);
    expect((stored()['libraryScan']! as Map)['minFileSizeKb'], 500);
    expect((stored()['playback']! as Map)['gapless'], false);
    expect((stored()['display']! as Map)['hiddenSidebarTabs'], [
      'albums',
      'artists',
      'folders',
      'genres',
      'languages',
    ]);
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
    notifier.setPlaylistsView(AlbumsView.list);
    await notifier.flush();
    expect(notified, 5);
    expect(SettingsFile(path).load(), container.read(settingsProvider));
    expect(stored()['albumsView'], 'list');
    expect(stored()['playlistsView'], 'list');

    File(path).deleteSync();
    notifier.setSongSort(const SortChoice(SongSortField.year));
    notifier.setAlbumsView(AlbumsView.list);
    notifier.setPlaylistsView(AlbumsView.list);
    await notifier.flush();
    expect(notified, 5);
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

  group('online lyrics consent', () {
    final lrclib = LyricsProviderRegistration(LrclibProvider());

    OnlineLyricsPrefs prefsOf(ProviderContainer c) =>
        c.read(settingsProvider).onlineLyrics;

    test('autoFetch stays off without the auto key', () async {
      final container = containerFor();
      final notifier = container.read(settingsProvider.notifier);

      notifier.setOnlineLyrics(const OnlineLyricsPrefs(autoFetch: true));
      expect(prefsOf(container).autoFetch, isFalse);

      notifier.acknowledgeOnlineLyricsNotice(lrclib.consentKey);
      notifier.setOnlineLyrics(const OnlineLyricsPrefs(autoFetch: true));
      expect(prefsOf(container).autoFetch, isFalse);
    });

    test('setOnlineLyrics keeps the acknowledged keys and saves the rest', () {
      final container = containerFor();
      final notifier = container.read(settingsProvider.notifier);
      notifier.acknowledgeOnlineLyricsNotice(lrclib.consentKey);

      notifier.setOnlineLyrics(
        const OnlineLyricsPrefs(writeLrc: true, noticeAcknowledged: {'x@y.z'}),
      );

      expect(prefsOf(container).writeLrc, isTrue);
      expect(prefsOf(container).noticeAcknowledged, {lrclib.consentKey});
    });

    test('enabling auto writes both keys and the flag in one save', () async {
      final container = containerFor();
      final notifier = container.read(settingsProvider.notifier);

      notifier.enableAutoOnlineLyrics(lrclib);
      await notifier.flush();

      expect(prefsOf(container).autoFetch, isTrue);
      expect(prefsOf(container).noticeAcknowledged, {
        lrclib.consentKey,
        lrclib.autoConsentKey,
      });
      final json = stored()['onlineLyrics']! as Map;
      expect(json['autoFetch'], true);
      expect(json['noticeAcknowledged'], [
        lrclib.consentKey,
        lrclib.autoConsentKey,
      ]);

      // The auto flag can now be switched with the setter.
      notifier.setOnlineLyrics(prefsOf(container).copyWith(autoFetch: false));
      expect(prefsOf(container).autoFetch, isFalse);
      notifier.setOnlineLyrics(prefsOf(container).copyWith(autoFetch: true));
      expect(prefsOf(container).autoFetch, isTrue);
    });

    test('autoAllowedFor needs the switch and the provider own auto key', () {
      const stale = OnlineLyricsPrefs(
        autoFetch: true,
        noticeAcknowledged: {'x@y.example:auto'},
      );
      expect(stale.autoAllowedFor(lrclib), isFalse);

      final ok = OnlineLyricsPrefs(
        autoFetch: true,
        noticeAcknowledged: {lrclib.autoConsentKey},
      );
      expect(ok.autoAllowedFor(lrclib), isTrue);
      expect(ok.copyWith(autoFetch: false).autoAllowedFor(lrclib), isFalse);
    });

    test('a manual acknowledgement does not enable auto', () {
      final container = containerFor();

      container
          .read(settingsProvider.notifier)
          .acknowledgeOnlineLyricsNotice(lrclib.consentKey);

      expect(prefsOf(container).autoFetch, isFalse);
      expect(prefsOf(container).hasAutoConsent, isFalse);
      expect(prefsOf(container).noticeAcknowledged, {lrclib.consentKey});
    });
  });

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
      await tick();
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

    test('a burst without flushing writes at most twice', () async {
      final container = slowContainer();
      final notifier = container.read(settingsProvider.notifier);

      for (var i = 0; i < 5; i++) {
        notifier.setTheme(
          i.isEven ? ThemePreference.dark : ThemePreference.light,
        );
        await tick();
      }
      for (var i = 0; i < 10; i++) {
        if (gated.pendingGates > 0) gated.finishNext();
        await tick();
        await tick();
      }
      await notifier.flush();

      expect(gated.started.length, lessThanOrEqualTo(2));
      expect(gated.started.last, container.read(settingsProvider));
    });

    test('a change right after a write finishes is still written', () async {
      final container = slowContainer();
      final notifier = container.read(settingsProvider.notifier);

      notifier.setTheme(ThemePreference.dark);
      await tick();
      gated.finishNext();
      notifier.setTheme(ThemePreference.light);
      await tick();
      await tick();
      gated.finishNext();
      await notifier.flush();

      expect(gated.saved.last.theme, ThemePreference.light);
    });

    test('a save that throws does not stop later changes', () async {
      final container = slowContainer();
      final notifier = container.read(settingsProvider.notifier);
      gated.throwOnNext = true;

      notifier.setTheme(ThemePreference.dark);
      await notifier.flush();
      expect(container.read(settingsSaveFailedProvider), isTrue);

      notifier.setTheme(ThemePreference.light);
      await tick();
      gated.finishNext();
      await notifier.flush();

      expect(gated.saved.last.theme, ThemePreference.light);
      expect(container.read(settingsSaveFailedProvider), isFalse);
    });

    test('a failure followed by a queued good write never flashes', () async {
      final container = slowContainer();
      final notifier = container.read(settingsProvider.notifier);
      final history = <bool>[];
      container.listen(settingsSaveFailedProvider, (_, v) => history.add(v));

      notifier.setTheme(ThemePreference.dark);
      await tick();
      notifier.setTheme(ThemePreference.light);
      gated.finishNext(succeed: false);
      await tick();
      await tick();
      gated.finishNext();
      await notifier.flush();

      expect(history, isNot(contains(true)));
      expect(container.read(settingsSaveFailedProvider), isFalse);
    });

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
  var throwOnNext = false;

  int get pendingGates => _gates.length - _finished;

  @override
  Future<bool> save(AppSettings settings) {
    started.add(settings);
    if (throwOnNext) {
      throwOnNext = false;
      throw StateError('disk on fire');
    }
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
