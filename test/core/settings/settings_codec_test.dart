import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/app_settings.dart';
import 'package:kanaru/core/settings/online_lyrics_prefs_codec.dart';
import 'package:kanaru/core/settings/settings_codec.dart';

void main() {
  test('an empty object gives defaults', () {
    final decoded = decodeSettings(<String, Object?>{});

    expect(decoded.settings, const AppSettings());
    expect(decoded.version, settingsSchemaVersion);
    expect(decoded.unknownKeys, isEmpty);
  });

  test('anything but an object gives defaults', () {
    for (final json in [null, 3, 'dark', <Object?>[]]) {
      expect(decodeSettings(json).settings, const AppSettings());
    }
  });

  test('round-trips every field', () {
    const settings = AppSettings(
      theme: ThemePreference.dark,
      languageCode: 'vi',
      titleBar: TitleBarPreference.none,
      songSort: SortChoice(SongSortField.duration, descending: true),
      albumSort: SortChoice(AlbumSortField.year),
      artistSort: SortChoice(ArtistSortField.albumCount, descending: true),
      albumsView: AlbumsView.list,
      playlistsView: AlbumsView.list,
    );

    final json = encodeSettings(settings);

    expect(json['version'], settingsSchemaVersion);
    expect(decodeSettings(json).settings, settings);
  });

  test('a wrong value falls back for that key only', () {
    final decoded = decodeSettings(<String, Object?>{
      'theme': 'purple',
      'language': 'vi',
      'titleBar': 2,
    });

    expect(decoded.settings, const AppSettings(languageCode: 'vi'));
  });

  test('rejects language values that are not a language code', () {
    for (final language in ['', 'VI', 'vi_VN', '../x', 7, true]) {
      expect(
        decodeSettings(<String, Object?>{'language': language})
            .settings
            .languageCode,
        isNull,
        reason: '$language',
      );
    }
  });

  test('keeps unknown keys and writes them back', () {
    final decoded = decodeSettings(<String, Object?>{
      'theme': 'light',
      'replayGain': 'album',
    });

    expect(decoded.unknownKeys, {'replayGain': 'album'});
    expect(
      encodeSettings(decoded.settings, unknownKeys: decoded.unknownKeys),
      containsPair('replayGain', 'album'),
    );
  });

  test('known keys win over unknown keys of the same name', () {
    final json = encodeSettings(
      const AppSettings(),
      unknownKeys: {'theme': 'dark', 'version': 9},
    );

    expect(json['theme'], 'system');
    expect(json['version'], settingsSchemaVersion);
  });

  test('reads the version, ignoring invalid ones', () {
    expect(decodeSettings(<String, Object?>{'version': 2}).version, 2);
    expect(
      decodeSettings(<String, Object?>{'version': '2'}).version,
      settingsSchemaVersion,
    );
    expect(
      decodeSettings(<String, Object?>{'version': 0}).version,
      settingsSchemaVersion,
    );
  });

  group('library sort', () {
    test('a file without the sort keys gives the defaults', () {
      final decoded = decodeSettings(<String, Object?>{
        'version': 1,
        'theme': 'dark',
        'language': 'vi',
        'titleBar': 'system',
      });

      expect(
        decoded.settings,
        const AppSettings(
          theme: ThemePreference.dark,
          languageCode: 'vi',
          titleBar: TitleBarPreference.system,
        ),
      );
      expect(decoded.settings.songSort, const SortChoice(SongSortField.title));
      expect(decoded.settings.albumsView, AlbumsView.grid);
      expect(decoded.settings.playlistsView, AlbumsView.grid);
      expect(decoded.librarySortExtra, isEmpty);
    });

    test('writes the documented shape', () {
      final json = encodeSettings(
        const AppSettings(
          albumSort: SortChoice(AlbumSortField.artist, descending: true),
        ),
      );

      expect(json['librarySort'], {
        'songs': {'by': 'title', 'descending': false},
        'albums': {'by': 'artist', 'descending': true},
        'artists': {'by': 'name', 'descending': false},
      });
      expect(json['albumsView'], 'grid');
      expect(json['playlistsView'], 'grid');
      expect(json['version'], 1);
    });

    test('each wrong part falls back on its own', () {
      final settings = decodeSettings(<String, Object?>{
        'librarySort': {
          'songs': {'by': 'playCount', 'descending': 'yes'},
          'albums': {'by': 7, 'descending': true},
          'artists': 'name',
        },
        'albumsView': 'carousel',
        'playlistsView': 'carousel',
      }).settings;

      expect(settings.songSort, const SortChoice(SongSortField.title));
      expect(
        settings.albumSort,
        const SortChoice(AlbumSortField.title, descending: true),
      );
      expect(settings.artistSort, const SortChoice(ArtistSortField.name));
      expect(settings.albumsView, AlbumsView.grid);
      expect(settings.playlistsView, AlbumsView.grid);
    });

    test('librarySort that is not an object gives the defaults', () {
      for (final value in [null, 3, 'albums', <Object?>[]]) {
        final decoded = decodeSettings(<String, Object?>{'librarySort': value});
        expect(decoded.settings, const AppSettings(), reason: '$value');
        expect(decoded.librarySortExtra, isEmpty);
        expect(decoded.unknownKeys, isEmpty);
      }
    });

    test('keeps screens it does not know and writes them back', () {
      final decoded = decodeSettings(<String, Object?>{
        'librarySort': {
          'folders': {'by': 'path', 'descending': true},
          'songs': {'by': 'year', 'descending': false},
        },
        'replayGain': 'album',
      });

      expect(decoded.librarySortExtra.keys, ['folders']);
      final json = encodeSettings(
        decoded.settings,
        unknownKeys: decoded.unknownKeys,
        librarySortExtra: decoded.librarySortExtra,
      );
      final sorts = json['librarySort']! as Map<String, Object?>;
      expect(sorts['folders'], {'by': 'path', 'descending': true});
      expect(sorts['songs'], {'by': 'year', 'descending': false});
      expect(json['replayGain'], 'album');
    });

    test('known screens win over unknown screens of the same name', () {
      final json = encodeSettings(
        const AppSettings(),
        librarySortExtra: {
          'songs': {'by': 'duration'},
        },
      );

      expect((json['librarySort']! as Map)['songs'], {
        'by': 'title',
        'descending': false,
      });
    });

    test('withLanguage keeps the library fields', () {
      const settings = AppSettings(
        songSort: SortChoice(SongSortField.album, descending: true),
        albumSort: SortChoice(AlbumSortField.dateAdded),
        artistSort: SortChoice(ArtistSortField.songCount),
        albumsView: AlbumsView.list,
        playlistsView: AlbumsView.list,
      );

      final changed = settings.withLanguage('vi');

      expect(changed.songSort, settings.songSort);
      expect(changed.albumSort, settings.albumSort);
      expect(changed.artistSort, settings.artistSort);
      expect(changed.albumsView, settings.albumsView);
      expect(changed.playlistsView, settings.playlistsView);
      expect(changed.withLanguage(null), settings);
    });

    test('the schema version stays 1', () {
      expect(settingsSchemaVersion, 1);
    });
  });

  group('library options', () {
    test('default to a rescan at start and a pending first run', () {
      final settings = decodeSettings(<String, Object?>{}).settings;

      expect(settings.rescanOnStartup, isTrue);
      expect(settings.libraryOnboarded, isFalse);
    });

    test('round-trip', () {
      const settings = AppSettings(
        rescanOnStartup: false,
        libraryOnboarded: true,
      );

      final json = encodeSettings(settings);

      expect(json['rescanOnStartup'], false);
      expect(json['libraryOnboarded'], true);
      expect(decodeSettings(json).settings, settings);
    });

    test('a value of the wrong type gives the default', () {
      final settings = decodeSettings(<String, Object?>{
        'rescanOnStartup': 'no',
        'libraryOnboarded': 1,
      }).settings;

      expect(settings.rescanOnStartup, isTrue);
      expect(settings.libraryOnboarded, isFalse);
    });

    test('are not kept as unknown keys', () {
      final decoded = decodeSettings(<String, Object?>{
        'rescanOnStartup': false,
        'libraryOnboarded': true,
        'futureKey': 1,
      });

      expect(decoded.unknownKeys, {'futureKey': 1});
    });
  });

  group('listen history', () {
    test('is recorded by default, also for a file without the key', () {
      expect(
        decodeSettings(<String, Object?>{}).settings.recordListenHistory,
        isTrue,
      );
      expect(const AppSettings().recordListenHistory, isTrue);
    });

    test('round-trips when turned off', () {
      const settings = AppSettings(recordListenHistory: false);

      final json = encodeSettings(settings);

      expect(json['recordListenHistory'], false);
      expect(decodeSettings(json).settings, settings);
      expect(settings.toString(), contains('recordListenHistory: false'));
    });

    test('a value of the wrong type gives the default', () {
      final decoded = decodeSettings(<String, Object?>{
        'recordListenHistory': 'no',
      });

      expect(decoded.settings.recordListenHistory, isTrue);
      expect(decoded.unknownKeys, isEmpty);
    });
  });

  group('animations', () {
    test('are on by default, also for a file without the key', () {
      expect(decodeSettings(<String, Object?>{}).settings.animations, isTrue);
      expect(const AppSettings().animations, isTrue);
    });

    test('round-trip when turned off', () {
      const settings = AppSettings(animations: false);

      final json = encodeSettings(settings);

      expect(json['animations'], false);
      expect(decodeSettings(json).settings, settings);
      expect(settings.toString(), contains('animations: false'));
    });

    test('a value of the wrong type gives the default', () {
      final decoded = decodeSettings(<String, Object?>{'animations': 'no'});

      expect(decoded.settings.animations, isTrue);
      expect(decoded.unknownKeys, isEmpty);
    });
  });

  group('lyricsTranslation group', () {
    const translated = AppSettings(
      translation: TranslationPrefs(
        show: true,
        service: LyricsTranslationService.deepl,
        targetLanguage: 'vi',
        noticeAcknowledged: {LyricsTranslationService.deepl},
      ),
    );

    test('is a known key and round-trips as a nested object', () {
      final json = encodeSettings(translated);
      final decoded = decodeSettings(json);

      expect((json['lyricsTranslation']! as Map)['service'], 'deepl');
      expect(decoded.settings, translated);
      expect(decoded.unknownKeys, isEmpty);
    });

    test('a file without it gives the defaults', () {
      expect(
        decodeSettings(<String, Object?>{}).settings.translation,
        const TranslationPrefs(),
      );
    });

    test('keys inside it are kept', () {
      final decoded = decodeSettings(<String, Object?>{
        'lyricsTranslation': <String, Object?>{'future': 2},
      });
      final json = encodeSettings(
        decoded.settings,
        groupExtras: decoded.groupExtras,
      );

      expect((json['lyricsTranslation']! as Map)['future'], 2);
    });

    test('never stores a credential', () {
      expect(encodeSettings(translated).toString(), isNot(contains('key')));
    });
  });

  group('preference groups', () {
    test('a file without them gives the defaults', () {
      final settings = decodeSettings(<String, Object?>{}).settings;

      expect(settings.libraryScan, const LibraryScanPrefs());
      expect(settings.playback, const PlaybackPrefs());
      expect(settings.display, const DisplayPrefs());
    });

    test('round-trip as nested objects', () {
      const settings = AppSettings(
        libraryScan: LibraryScanPrefs(minFileSizeKb: 500),
        playback: PlaybackPrefs(gapless: false),
        display: DisplayPrefs(fontScale: 1.2),
      );

      final json = encodeSettings(settings);

      expect((json['libraryScan']! as Map)['minFileSizeKb'], 500);
      expect((json['playback']! as Map)['gapless'], false);
      expect((json['display']! as Map)['fontScale'], 1.2);
      expect(decodeSettings(json).settings, settings);
    });

    test('are known keys, not left over as unknown ones', () {
      final decoded = decodeSettings(<String, Object?>{
        'libraryScan': <String, Object?>{},
        'playback': <String, Object?>{},
        'display': <String, Object?>{},
      });

      expect(decoded.unknownKeys, isEmpty);
    });

    test(
      'keys inside a group are kept, an object of the wrong type is not',
      () {
        final decoded = decodeSettings(<String, Object?>{
          'playback': <String, Object?>{'eq': 1},
          'display': 'bad',
        });
        final json = encodeSettings(
          decoded.settings,
          groupExtras: decoded.groupExtras,
        );

        expect((json['playback']! as Map)['eq'], 1);
        expect(decoded.groupExtras['display'], isEmpty);
        expect(json['display'], isA<Map<String, Object?>>());
      },
    );

    test('settings that differ only in a group are not equal', () {
      expect(
        const AppSettings(playback: PlaybackPrefs(gapless: false)),
        isNot(const AppSettings()),
      );
      expect(
        const AppSettings(playback: PlaybackPrefs(gapless: false)).hashCode,
        isNot(const AppSettings().hashCode),
      );
    });
  });

  group('onlineLyrics group', () {
    OnlineLyricsPrefs decode(Object? group) =>
        decodeSettings(<String, Object?>{'onlineLyrics': group})
            .settings
            .onlineLyrics;

    test('a file without it gives the defaults, everything off', () {
      final prefs = decodeSettings(<String, Object?>{}).settings.onlineLyrics;

      expect(prefs, const OnlineLyricsPrefs());
      expect(prefs.autoFetch, isFalse);
      expect(prefs.manualConsent, isFalse);
      expect(prefs.autoConsent, isFalse);
    });

    test('round-trips as a nested known key', () {
      const settings = AppSettings(
        onlineLyrics: OnlineLyricsPrefs(
          autoFetch: true,
          manualConsent: true,
          autoConsent: true,
        ),
      );
      final json = encodeSettings(settings);
      final decoded = decodeSettings(json);

      expect((json['onlineLyrics']! as Map).containsKey('writeLrc'), isFalse);
      expect(decoded.settings, settings);
      expect(decoded.unknownKeys, isEmpty);
    });

    test('autoFetch without the automatic consent reads as off', () {
      final prefs = decode(<String, Object?>{
        'autoFetch': true,
        'manualConsent': true,
      });

      expect(prefs.autoFetch, isFalse);
      expect(prefs.manualConsent, isTrue);
    });

    test('autoFetch with the automatic consent stays on', () {
      expect(
        decode(<String, Object?>{
          'autoFetch': true,
          'manualConsent': true,
          'autoConsent': true,
        }).autoFetch,
        isTrue,
      );
    });

    test('unknown keys are kept', () {
      final decoded = decodeSettings(<String, Object?>{
        'onlineLyrics': <String, Object?>{'future': 2, 'manualConsent': true},
      });
      final json = encodeSettings(
        decoded.settings,
        groupExtras: decoded.groupExtras,
      );

      expect((json['onlineLyrics']! as Map)['future'], 2);
    });

    test('a value of the wrong type gives that key its default', () {
      final prefs = decode(<String, Object?>{
        'autoFetch': 'yes',
        'manualConsent': 'lrclib@lrclib.net',
        'autoConsent': 1,
      });

      expect(prefs, const OnlineLyricsPrefs());
      expect(decode('nope'), const OnlineLyricsPrefs());
    });

    test('the legacy writeLrc key is dropped, not kept as an extra', () {
      final (prefs, extra) = decodeOnlineLyricsPrefs(<String, Object?>{
        'writeLrc': true,
      });

      expect(prefs, const OnlineLyricsPrefs());
      expect(extra, isEmpty);
      expect(
        encodeOnlineLyricsPrefs(prefs, extra: extra).keys,
        isNot(contains('writeLrc')),
      );
    });
  });
}
