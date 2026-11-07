import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_content_hash.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_controller.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_prefetch.dart';
import 'package:kanaru/core/lyrics_translation/translation_prefetch_clock.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_plugin_runner.dart';
import 'fake_translator.dart';
import '../lyrics/fake_lyrics_readers.dart';

const _delay = Duration(seconds: 10);
const _ownId = 'plugin-bbbbbbbbbbbb';

final _default = testTranslatePlugin;
final _own = TranslationServiceId.tryParse(_ownId)!;

String _text(String name) => 'one $name\ntwo $name';

String _hashOf(String name) => lyricsContentHash(
  Lyrics(
    lines: [
      for (final t in _text(name).split('\n')) LyricLine(Duration.zero, t),
    ],
    synced: false,
    source: LyricsSource.embedded,
  ),
);

Track _track(String name) => Track(uri: '/m/$name.mp3', title: name);

AppSettings _settings({
  bool show = true,
  int count = 2,
  Set<TranslationServiceId>? acknowledged,
  int? allChosenAt,
  TranslationScopePrecedence precedence = TranslationScopePrecedence.replaceAll,
}) => AppSettings(
  translation: TranslationPrefs(
    show: show,
    service: _default,
    noticeAcknowledged: acknowledged ?? {_default, _own},
    prefetchCount: count,
    allChosenAt: allChosenAt,
    scopePrecedence: precedence,
  ),
);

/// Time the prefetch clock reads, moved by hand.
class _FakeTime extends PrefetchTimeSource {
  var _now = Duration.zero;
  final _timers = <(Duration, void Function(), _Handle)>[];

  @override
  Duration now() => _now;

  @override
  Timer timer(Duration after, void Function() onFire) {
    final handle = _Handle();
    _timers.add((_now + after, onFire, handle));
    return handle;
  }

  void advance(Duration by) {
    _now += by;
    final due = [
      for (final t in _timers)
        if (!t.$3.cancelled && t.$1 <= _now) t,
    ];
    _timers.removeWhere((t) => due.contains(t) || t.$3.cancelled);
    for (final t in due) {
      t.$3.fired = true;
      t.$2();
    }
  }
}

class _Handle implements Timer {
  var cancelled = false;
  var fired = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => 0;
}

void main() {
  late LibraryDatabase db;
  late FakePluginRunner runner;
  late FakeEmbeddedLyricsReader lyrics;
  late ProviderContainer container;
  late int onlineReads;
  late _FakeTime time;
  ProviderSubscription<Object?>? controller;

  setUp(() {
    db = memoryDb();
    runner = FakePluginRunner();
    lyrics = FakeEmbeddedLyricsReader();
    onlineReads = 0;
    time = _FakeTime();
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Queue a, b, c, d (a plays) with lyrics for each but those in [without].
  Future<void> start({
    AppSettings? settings,
    Set<String> without = const {},
    List<String> names = const ['a', 'b', 'c', 'd'],
    bool withController = false,
  }) async {
    for (final n in names) {
      if (!without.contains(n)) {
        lyrics.byPath['/m/$n.mp3'] = (text: _text(n), synced: const []);
      }
    }
    container = translationContainer(
      db: db,
      lyrics: lyrics,
      plugin: runner,
      settings: settings ?? _settings(),
      overrides: [
        ...translatePluginOverrides(
          runner: runner,
          records: [
            translateRecord(testTranslatePluginId),
            translateRecord(_ownId),
          ],
        ),
        translationPrefetchDelayProvider.overrideWithValue(_delay),
        translationPrefetchTimeProvider.overrideWithValue(time),
        lyricsProvidersProvider.overrideWith((ref) {
          onlineReads++;
          return const [];
        }),
      ],
    );
    await songChoicesLoaded(container);
    if (withController) {
      controller = container.listen(lyricsTranslationProvider('en'), (_, _) {});
    } else {
      container.listen(translationPrefetchProvider('en'), (_, _) {});
    }
    await container.read(playerServiceProvider.notifier).openTracks([
      for (final n in names) _track(n),
    ]);
    await settle();
  }

  /// Waits until no new request has gone out for a while.
  Future<void> idle() async {
    var seen = -1;
    while (seen != runner.calls.length) {
      seen = runner.calls.length;
      await settle(const Duration(milliseconds: 150));
    }
  }

  /// Lets the delay of the playthrough pass, then the work finish.
  Future<void> after() async {
    time.advance(_delay);
    await idle();
  }

  PlayerService player() => container.read(playerServiceProvider.notifier);
  Future<void> seed(String name, String provider) => db.saveLyricTranslation(
    LyricTranslationsCompanion.insert(
      contentHash: _hashOf(name),
      provider: provider,
      targetLang: 'en',
      linesJson: '{"one $name":"x","two $name":"y"}',
      createdAt: 1,
    ),
  );
  Future<List<String>> providersOf(String name) async => [
    for (final r in await db.watchLyricTranslations(_hashOf(name), 'en').first)
      r.provider,
  ];
  // The first line of each chunk that went out, by track name.
  List<String> sent() => [
    for (final c in runner.calls) c.first.replaceFirst('one ', ''),
  ];

  group('what is translated', () {
    test('after the delay, the next songs one after the other', () async {
      final hold = runner.hold = Completer<void>();
      await start();
      time.advance(_delay ~/ 2);
      await idle();
      expect(runner.calls, isEmpty);

      await after();
      expect(sent(), ['b']);
      // The second song waits for the first.
      await after();
      expect(sent(), ['b']);
      hold.complete();
      await after();
      expect(sent(), ['b', 'c']);
      expect(runner.targets, ['en', 'en']);
    });

    test('a count of zero asks for nothing', () async {
      await start(settings: _settings(count: 0));
      await after();
      expect(runner.calls, isEmpty);
    });

    test('translation switched off asks for nothing', () async {
      await start(settings: _settings(show: false));
      await after();
      expect(runner.calls, isEmpty);
    });

    test('a service without an accepted notice is not asked', () async {
      await start(settings: _settings(acknowledged: {}));
      await after();
      expect(runner.calls, isEmpty);
    });

    test(
      'a song without lyrics is skipped and no online lookup is made',
      () async {
        await start(without: {'b'}, settings: _settings(count: 3));
        await after();
        expect(sent(), ['c', 'd']);
        expect(onlineReads, 0);
      },
    );

    test('a saved translation by any plugin means no request', () async {
      await seed('b', _ownId);
      await start(settings: _settings(count: 3));
      await after();
      expect(sent(), ['c', 'd']);
    });

    test('a song with its own plugin uses it', () async {
      await db.setSongTranslationService(_hashOf('b'), _ownId, chosenAt: 10);
      await start(settings: _settings(count: 1, allChosenAt: 5));
      await after();
      expect(await providersOf('b'), [_ownId]);
    });

    test('keep-custom: the older song choice wins over "All songs"', () async {
      await db.setSongTranslationService(_hashOf('b'), _ownId, chosenAt: 10);
      await start(
        settings: _settings(
          count: 1,
          allChosenAt: 20,
          precedence: TranslationScopePrecedence.keepCustom,
        ),
      );
      await after();
      expect(await providersOf('b'), [_ownId]);
    });

    test(
      'replace-all: the newer "All songs" wins over the song choice',
      () async {
        await db.setSongTranslationService(_hashOf('b'), _ownId, chosenAt: 10);
        await start(
          settings: _settings(
            count: 1,
            allChosenAt: 20,
            precedence: TranslationScopePrecedence.replaceAll,
          ),
        );
        await after();
        expect(await providersOf('b'), [testTranslatePluginId]);
        // The song's own choice is never removed.
        expect(await db.watchSongTranslationOverrides().first, hasLength(1));
      },
    );

    test(
      'changing the precedence mid-round waits for the job in flight',
      () async {
        final hold = runner.hold = Completer<void>();
        await db.setSongTranslationService(_hashOf('c'), _ownId, chosenAt: 10);
        await start(settings: _settings(allChosenAt: 20));
        await after();
        expect(sent(), ['b']);

        container
            .read(settingsProvider.notifier)
            .setTranslation(
              container
                  .read(settingsProvider)
                  .translation
                  .copyWith(
                    scopePrecedence: TranslationScopePrecedence.keepCustom,
                  ),
            );
        await after();
        expect(sent(), ['b']);

        hold.complete();
        await after();
        expect(sent(), ['b', 'c']);
        expect(await providersOf('c'), [_ownId]);
      },
    );

    test(
      'the playing song without lyrics does not stop the next ones',
      () async {
        await start(without: {'a'});
        await after();
        expect(sent(), ['b', 'c']);
      },
    );

    test('a remote song is skipped', () async {
      lyrics.byPath['/m/c.mp3'] = (text: _text('c'), synced: const []);
      await start(names: ['a']);
      await player().openTracks([
        _track('a'),
        const Track(uri: 'https://x.test/b.mp3', title: 'b'),
        _track('c'),
      ]);
      await after();
      expect(sent(), ['c']);
    });
  });

  group('when it starts', () {
    test(
      'paused: not yet; playing again: after the rest of the delay',
      () async {
        await start();
        await player().pause();
        await after();
        expect(runner.calls, isEmpty);
        await player().play();
        await after();
        expect(sent(), ['b', 'c']);
      },
    );

    test('a seek far into the song does not count', () async {
      await start();
      await player().seek(const Duration(minutes: 2));
      time.advance(_delay ~/ 2);
      await idle();
      expect(runner.calls, isEmpty);
    });

    test('a new playthrough starts the delay again', () async {
      await start();
      time.advance(_delay * 0.6);
      await player().next();
      time.advance(_delay * 0.6);
      await idle();
      expect(runner.calls, isEmpty);
      await after();
      expect(sent(), ['c', 'd']);
    });

    test('the delay played for one song does not serve the next', () async {
      await start();
      await after();
      expect(sent(), ['b', 'c']);
      await player().next();
      await idle();
      expect(sent(), ['b', 'c']);
      await after();
      expect(sent(), ['b', 'c', 'd']);
    });
  });

  group('rounds', () {
    test('the queue changing mid-round: the job in flight saves, no second '
        'one runs beside it', () async {
      final hold = runner.hold = Completer<void>();
      await start();
      await after();
      expect(sent(), ['b']);

      await player().removeTrack(2);
      await after();
      expect(sent(), ['b']);

      hold.complete();
      await after();
      expect(sent(), ['b', 'd']);
      expect(
        await db.watchLyricTranslations(_hashOf('b'), 'en').first,
        hasLength(1),
      );
    });

    test(
      'changing the song keeps the prefetcher alive and the running job',
      () async {
        final hold = runner.hold = Completer<void>();
        await start();
        await after();
        expect(sent(), ['b']);
        await player().next();
        await after();
        hold.complete();
        await after();
        // b saved, then the new window (c, d) is done.
        expect(sent(), ['b', 'c', 'd']);
      },
    );

    test('a rate limit stops every request for that service', () async {
      runner.errors[0] = failure(TranslationFailureKind.rateLimited);
      await start();
      await after();
      expect(sent(), ['b']);
      await player().next();
      await after();
      expect(sent(), ['b']);
    });

    test('disposing starts nothing more', () async {
      await start();
      await idle();
      container.dispose();
      await after();
      expect(runner.calls, isEmpty);
      container = ProviderContainer();
    });

    test(
      'a changed default language starts again in the new language',
      () async {
        final hold = runner.hold = Completer<void>();
        await start(settings: _settings(count: 1));
        await after();
        expect(runner.targets, ['en']);
        container
            .read(settingsProvider.notifier)
            .setTranslation(
              container
                  .read(settingsProvider)
                  .translation
                  .withTargetLanguage('vi'),
            );
        hold.complete();
        await idle();
        expect(runner.targets, ['en', 'vi']);
      },
    );
  });

  group('with the controller', () {
    test('waits while the playing song is translating, then starts', () async {
      final hold = runner.hold = Completer<void>();
      await start(withController: true);
      await until(() => runner.calls.isNotEmpty);
      time.advance(_delay);
      await idle();
      expect(sent(), ['a']);
      hold.complete();
      await until(() => sent().length >= 3);
      await idle();
      expect(sent(), ['a', 'b', 'c']);
    });

    test('the prefetcher survives a song change', () async {
      await start(withController: true);
      final before = container.read(translationPrefetchProvider('en').notifier);
      await player().next();
      await idle();
      expect(
        identical(
          container.read(translationPrefetchProvider('en').notifier),
          before,
        ),
        isTrue,
      );
    });

    test('closing the controller during a background job asks for nothing '
        'more', () async {
      final hold = runner.hold = Completer<void>();
      await start(without: {'a'}, withController: true);
      container.listen(translationJobsProvider, (_, _) {});
      time.advance(_delay);
      await until(() => runner.calls.isNotEmpty);
      expect(sent(), ['b']);
      controller!.close();
      await settle(const Duration(milliseconds: 100));
      hold.complete();
      await idle();
      expect(sent(), ['b']);
    });
  });
}
