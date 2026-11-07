import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_content_hash.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope_providers.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_plugin_runner.dart';
import 'fake_translator.dart';
import 'lyrics_translation_controller_test.dart' show Rig;

const _text = 'alpha\nbeta\ngamma';
const _idle = Duration(milliseconds: 700);
const _ownId = 'plugin-bbbbbbbbbbbb';
const _thirdId = 'plugin-cccccccccccc';

final _default = testTranslatePlugin;
final _own = TranslationServiceId.tryParse(_ownId)!;
final _third = TranslationServiceId.tryParse(_thirdId)!;

final _hash = lyricsContentHash(
  Lyrics(
    lines: [for (final t in _text.split('\n')) LyricLine(Duration.zero, t)],
    synced: false,
    source: LyricsSource.embedded,
  ),
);

AppSettings _settings({int? allChosenAt}) => AppSettings(
  translation: TranslationPrefs(
    show: true,
    service: _default,
    noticeAcknowledged: {_default, _own, _third},
    allChosenAt: allChosenAt,
  ),
);

void main() {
  late LibraryDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  Rig makeRig(
    FakePluginRunner plugin, {
    int? allChosenAt,
    List<Override>? overrides,
  }) => Rig(
    db,
    plugin: plugin,
    settings: _settings(allChosenAt: allChosenAt),
    overrides:
        overrides ??
        translatePluginOverrides(
          runner: plugin,
          records: [
            translateRecord(testTranslatePluginId),
            translateRecord(_ownId),
            translateRecord(_thirdId),
          ],
        ),
  );

  Future<void> seedCache(String provider) => db.saveLyricTranslation(
    LyricTranslationsCompanion.insert(
      contentHash: _hash,
      provider: provider,
      targetLang: 'en',
      sourceLang: const Value('ja'),
      linesJson: '{"alpha":"x","beta":"y","gamma":"z"}',
      createdAt: 1,
    ),
  );

  TranslationChoice? choiceOf(Rig rig) => switch (rig.state) {
    TranslationReady(:final info) => info.choice,
    TranslationOff(:final info) => info.choice,
    TranslationLoading(:final info) => info.choice,
    _ => null,
  };

  group('which service the song uses', () {
    test('a song choice newer than "All songs" translates with it', () async {
      await db.setSongTranslationService(_hash, _ownId, chosenAt: 10);
      final rig = makeRig(FakePluginRunner(), allChosenAt: 5);
      await rig.play('/m/a.mp3', _text);
      await rig.untilReady();

      final ready = rig.state as TranslationReady;
      expect(ready.service, _own);
      expect(ready.info.choice?.scope, TranslationScope.song);
      expect(ready.info.choice?.defaultService, _default);
      rig.dispose();
    });

    test(
      'a newer "All songs" wins and the song row stays in the database',
      () async {
        await db.setSongTranslationService(_hash, _ownId, chosenAt: 10);
        final rig = makeRig(FakePluginRunner(), allChosenAt: 20);
        await rig.play('/m/a.mp3', _text);
        await rig.untilReady();

        final ready = rig.state as TranslationReady;
        expect(ready.service, _default);
        expect(ready.info.choice?.scope, TranslationScope.all);
        final rows = await db.watchSongTranslationOverrides().first;
        expect(rows.single.service, _ownId);
        rig.dispose();
      },
    );

    test(
      'an older song choice still shows its saved version, no request',
      () async {
        await db.setSongTranslationService(_hash, _ownId, chosenAt: 10);
        await seedCache(_ownId);
        final plugin = FakePluginRunner();
        final rig = makeRig(plugin, allChosenAt: 20);
        await rig.play('/m/a.mp3', _text);
        await settle(_idle);

        final ready = rig.state as TranslationReady;
        expect(ready.service, _own);
        expect(ready.fromOtherService, isTrue);
        expect(ready.info.choice?.service, _default);
        expect(plugin.calls, isEmpty);
        rig.dispose();
      },
    );

    test(
      'changing the default in Settings does not beat a song choice',
      () async {
        await db.setSongTranslationService(_hash, _ownId, chosenAt: 10);
        final rig = makeRig(FakePluginRunner());
        await rig.play('/m/a.mp3', _text);
        await rig.untilReady();

        rig.settings.setTranslation(
          rig.container
              .read(settingsProvider)
              .translation
              .copyWith(service: _third),
        );
        await settle(_idle);

        expect(choiceOf(rig)?.service, _own);
        expect(choiceOf(rig)?.defaultService, _third);
        rig.dispose();
      },
    );

    test('while the song choices load the state is Loading, not Off', () async {
      final plugin = FakePluginRunner();
      final rig = makeRig(
        plugin,
        overrides: [
          ...translatePluginOverrides(runner: plugin),
          songTranslationOverridesProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
      );
      await rig.play('/m/a.mp3', _text);
      await settle(_idle);

      expect(rig.state, isA<TranslationLoading>());
      expect(plugin.calls, isEmpty);
      rig.dispose();
    });

    test('a failed plugin read keeps the unavailable state', () async {
      final plugin = FakePluginRunner();
      final rig = makeRig(
        plugin,
        overrides: [
          translatePluginRecordsProvider.overrideWithValue(
            AsyncValue.error(StateError('x'), StackTrace.empty),
          ),
        ],
      );
      await rig.play('/m/a.mp3', _text);
      await settle(_idle);

      expect(rig.state, isA<TranslationUnavailable>());
      expect(plugin.calls, isEmpty);
      rig.dispose();
    });
  });

  group('rebuilds when only the scope changes', () {
    test('"All songs" with the very same default service moves the song to '
        'the default', () async {
      await db.setSongTranslationService(_hash, _ownId, chosenAt: 10);
      final rig = makeRig(FakePluginRunner());
      await rig.play('/m/a.mp3', _text);
      await rig.untilReady();
      expect((rig.state as TranslationReady).service, _own);
      expect(rig.plugin.calls, hasLength(1));

      // Same service as the default: only allChosenAt changes. The version
      // saved for the song's own service stays on screen, no request is made.
      rig.settings.enableTranslation(_default, allChosenAt: 20);
      await settle(_idle);

      final after = rig.state as TranslationReady;
      expect(after.service, _own);
      expect(after.fromOtherService, isTrue);
      expect(after.info.choice?.service, _default);
      expect(after.info.choice?.scope, TranslationScope.all);
      expect(rig.plugin.calls, hasLength(1));
      rig.dispose();
    });

    test('the same service with another scope is a different state', () async {
      await seedCache(testTranslatePluginId);
      await db.setSongTranslationService(
        _hash,
        testTranslatePluginId,
        chosenAt: 10,
      );
      final rig = makeRig(FakePluginRunner());
      await rig.play('/m/a.mp3', _text);
      await settle(_idle);
      final before = rig.state as TranslationReady;
      expect(before.service, _default);
      expect(before.info.choice?.scope, TranslationScope.song);

      rig.settings.enableTranslation(_default, allChosenAt: 20);
      await settle(_idle);

      final after = rig.state as TranslationReady;
      expect(after.service, _default);
      expect(after.info.choice?.scope, TranslationScope.all);
      expect(after, isNot(before));
      rig.dispose();
    });
  });
}
