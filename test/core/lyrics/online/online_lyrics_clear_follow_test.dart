import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_streams.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_controller.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/secrets/secret_store_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import '../../lyrics_translation/fake_plugin_runner.dart';
import 'fake_lyrics_provider.dart';
import 'status_test_rig.dart';

/// Waits for [done] in real time, with room for a slow cold run.
Future<void> untilSlow(bool Function() done) async {
  final end = DateTime.now().add(const Duration(seconds: 15));
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('condition not reached in 15 s');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  Future<(StatusRig, FakePluginRunner)> make({
    required bool auto,
    Duration tDebounce = const Duration(milliseconds: 30),
  }) async {
    final plugin = FakePluginRunner();
    final rig = await createStatusRig(
      autoFetch: auto,
      overrides: [
        ...translatePluginOverrides(runner: plugin),
        secretStoreProvider.overrideWith(
          (ref) async => ResolvedSecretStore(
            MemorySecretStore(),
            usingFallback: false,
            persistent: false,
          ),
        ),
        translationDebounceProvider.overrideWithValue(tDebounce),
      ],
    );
    final s = rig.container.read(settingsProvider.notifier);
    s.enableTranslation(testTranslatePlugin);
    return (rig, plugin);
  }

  Future<void> seedFound(StatusRig rig, String uri) =>
      rig.h.db.saveOnlineLyrics(
        OnlineLyricsCompanion.insert(
          cacheKey: LyricsTarget.fromTrack(fakeSong(uri)).cacheKey,
          providerId: 'fake',
          status: 'found',
          remoteId: const Value('1'),
          syncedText: const Value('[00:01.00] hello'),
          fetchedAt: rig.h.now.millisecondsSinceEpoch,
        ),
      );

  test(
    'translated online song: Clear -> translation unavailable, no new call',
    () async {
      final (rig, plugin) = await make(auto: false);
      await seedFound(rig, '/m/a.flac');
      rig.watch();
      final states = <LyricsTranslationState>[];
      rig.container.listen(
        lyricsTranslationProvider('en'),
        (_, n) => states.add(n),
        fireImmediately: true,
      );
      await rig.play([fakeSong('/m/a.flac')]);
      await rig.until(
        () =>
            rig.container.read(lyricsTranslationProvider('en'))
                is TranslationReady,
      );
      expect(plugin.calls, hasLength(1));
      await rig.h.db.clearOnlineLyrics();
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();
      expect(
        rig.container.read(lyricsTranslationProvider('en')),
        isA<TranslationUnavailable>(),
      );
      expect(plugin.calls, hasLength(1));
      expect(rig.requests, 0);
    },
  );

  test('Clear within the translation debounce: nothing sent', () async {
    final (rig, plugin) = await make(
      auto: false,
      tDebounce: const Duration(milliseconds: 300),
    );
    await seedFound(rig, '/m/a.flac');
    rig.watch();
    rig.container.listen(
      lyricsTranslationProvider('en'),
      (_, _) {},
      fireImmediately: true,
    );
    await rig.play([fakeSong('/m/a.flac')]);
    await rig.until(() => rig.status is LyricsFound);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await rig.h.db.clearOnlineLyrics();
    await rig.until(() => rig.status is LyricsNone);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(plugin.calls, isEmpty);
    expect(
      rig.container.read(lyricsTranslationProvider('en')),
      isA<TranslationUnavailable>(),
    );
  });

  test('auto on: Clear starts a new debounced lookup', () async {
    final (rig, _) = await make(auto: true);
    rig.fake.lookupResult = fakeCandidate();
    rig.watch();
    await rig.play([fakeSong('/m/a.flac')]);
    await untilSlow(() => rig.status is LyricsFound);
    final before = rig.requests;
    expect(before, 1);
    // The answer shows before the cache stream does; the one-shot lookup
    // stays watched until then, and a Clear inside that window would reuse
    // the finished lookup instead of starting a new one.
    await untilSlow(
      () =>
          rig.container
              .read(
                onlineLyricsCacheProvider(
                  LyricsTarget.fromTrack(fakeSong('/m/a.flac')).cacheKey,
                ),
              )
              .value
              ?.isNotEmpty ??
          false,
    );
    await rig.settle();

    await rig.h.db.clearOnlineLyrics();
    await untilSlow(() => rig.requests == before + 1);
    await untilSlow(() => rig.status is LyricsFound);
    await rig.settle();
    expect(rig.requests, before + 1);
  });
}
