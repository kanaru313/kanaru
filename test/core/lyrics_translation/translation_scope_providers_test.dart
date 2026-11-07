import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_clock.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope_providers.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:logging/logging.dart';

import 'fake_plugin_runner.dart';
import 'fake_translator.dart';

const _ownId = 'plugin-bbbbbbbbbbbb';
final _default = testTranslatePlugin;
final _own = TranslationServiceId.tryParse(_ownId)!;

void main() {
  late LibraryDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  ProviderContainer make({LibraryDatabase? database, int? allChosenAt}) {
    final container = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(database),
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            translation: TranslationPrefs(
              show: true,
              service: _default,
              noticeAcknowledged: {_default},
              allChosenAt: allChosenAt,
            ),
          ),
        ),
        ...translatePluginOverrides(
          records: [
            translateRecord(testTranslatePluginId),
            translateRecord(_ownId),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('songTranslationOverridesProvider', () {
    test('loads as unknown, then holds the rows by hash', () async {
      await db.setSongTranslationService('h1', _ownId, chosenAt: 5);
      final container = make(database: db);
      container.listen(songTranslationOverridesProvider, (_, _) {});

      expect(container.read(songTranslationOverridesProvider).isLoading, true);
      final map = await container.read(songTranslationOverridesProvider.future);
      expect(map.keys, ['h1']);
      expect(map['h1']!.service, _ownId);
      expect(map['h1']!.chosenAt, 5);
    });

    test('follows the database', () async {
      final container = make(database: db);
      container.listen(songTranslationOverridesProvider, (_, _) {});
      expect(
        await container.read(songTranslationOverridesProvider.future),
        isEmpty,
      );

      await db.setSongTranslationService('h2', _ownId, chosenAt: 7);
      await until(
        () =>
            container
                .read(songTranslationOverridesProvider)
                .value
                ?.isNotEmpty ==
            true,
      );
      await db.setSongTranslationService('h2', null, chosenAt: null);
      await until(
        () =>
            container.read(songTranslationOverridesProvider).value?.isEmpty ==
            true,
      );
    });

    test('without a database it is empty, not loading forever', () async {
      final container = make();
      container.listen(songTranslationOverridesProvider, (_, _) {});
      expect(
        await container.read(songTranslationOverridesProvider.future),
        isEmpty,
      );
    });

    test('a failing read is logged once and counts as no choices', () async {
      // A read that fails: the table the stream selects from is gone.
      final broken = memoryDb();
      await broken.customStatement('DROP TABLE lyric_translation_prefs');
      addTearDown(broken.close);
      final records = <LogRecord>[];
      final sub = Logger('translation').onRecord.listen(records.add);
      addTearDown(sub.cancel);
      final container = make(database: broken);
      container.listen(songTranslationOverridesProvider, (_, _) {});

      final map = await container.read(songTranslationOverridesProvider.future);

      expect(map, isEmpty);
      expect(
        records.where((r) => r.message.contains('song translation choices')),
        hasLength(1),
      );
    });
  });

  group('translationChoiceFor', () {
    final choiceProvider = Provider.family<TranslationChoice?, String>(
      (ref, hash) => translationChoiceFor(ref.watch, hash),
    );

    test('is unknown while the song choices load, then resolves', () async {
      await db.setSongTranslationService('h1', _ownId, chosenAt: 10);
      final container = make(database: db, allChosenAt: 5);
      container.listen(choiceProvider('h1'), (_, _) {});
      expect(container.read(choiceProvider('h1')), isNull);

      await container.read(songTranslationOverridesProvider.future);
      final choice = container.read(choiceProvider('h1'))!;
      expect(choice.service, _own);
      expect(choice.scope, TranslationScope.song);
      // A song without a row follows the default.
      expect(container.read(choiceProvider('other'))!.service, _default);
    });

    test('is unknown while the plugin records load or failed', () async {
      for (final records in <AsyncValue<List<LyricsPluginRecord>>>[
        const AsyncValue.loading(),
        AsyncValue.error(StateError('x'), StackTrace.empty),
      ]) {
        final container = ProviderContainer(
          overrides: [
            libraryDatabaseProvider.overrideWithValue(null),
            translatePluginRecordsProvider.overrideWithValue(records),
          ],
        );
        addTearDown(container.dispose);
        container.listen(songTranslationOverridesProvider, (_, _) {});
        await container.read(songTranslationOverridesProvider.future);
        expect(container.read(choiceProvider('h')), isNull);
      }
    });

    test('reads the tune; an unreadable one is no tune', () async {
      await db.setSongTranslationService('h1', _ownId, chosenAt: 10);
      await db.customStatement(
        "UPDATE lyric_translation_prefs SET tune_json = "
        "'{\"model\":\"m\",\"style\":\"s\",\"n\":3}' WHERE content_hash = 'h1'",
      );
      await db.setSongTranslationService('h2', _ownId, chosenAt: 10);
      await db.customStatement(
        "UPDATE lyric_translation_prefs SET tune_json = 'not json' "
        "WHERE content_hash = 'h2'",
      );
      final container = make(database: db);
      container.listen(choiceProvider('h1'), (_, _) {});
      await container.read(songTranslationOverridesProvider.future);

      expect(container.read(choiceProvider('h1'))!.tune, {
        'model': 'm',
        'style': 's',
      });
      expect(container.read(choiceProvider('h2'))!.tune, isEmpty);
    });

    test('a row of another song does not rebuild this song', () async {
      await db.setSongTranslationService('h1', _ownId, chosenAt: 10);
      final container = make(database: db);
      var builds = 0;
      final counted = Provider<TranslationChoice?>((ref) {
        builds++;
        return translationChoiceFor(ref.watch, 'h1');
      });
      container.listen(counted, (_, _) {});
      await container.read(songTranslationOverridesProvider.future);
      await pumpEventQueue();
      container.read(counted);
      final after = builds;

      await db.setSongTranslationService('h9', _ownId, chosenAt: 11);
      await until(
        () =>
            container.read(songTranslationOverridesProvider).value?.length == 2,
      );
      await pumpEventQueue();

      expect(builds, after);

      await db.setSongTranslationService('h1', null, chosenAt: null);
      await until(() => builds > after);
      expect(container.read(counted)!.scope, TranslationScope.all);
    });

    test('readTranslationChoiceFor applies the same rule', () async {
      await db.setSongTranslationService('h1', _ownId, chosenAt: 10);
      final container = make(database: db, allChosenAt: 20);
      container.listen(songTranslationOverridesProvider, (_, _) {});
      await container.read(songTranslationOverridesProvider.future);
      final read = Provider<TranslationChoice?>(
        (ref) => readTranslationChoiceFor(ref, 'h1'),
      );

      expect(container.read(read)!.service, _default);
      expect(container.read(read), container.read(choiceProvider('h1')));
    });
  });

  test('the clock reads the current time and can be replaced', () {
    final real = ProviderContainer();
    addTearDown(real.dispose);
    final now = DateTime.now().millisecondsSinceEpoch;
    expect(real.read(translationClockProvider)(), greaterThanOrEqualTo(now));

    final fake = ProviderContainer(
      overrides: [translationClockProvider.overrideWithValue(() => 123)],
    );
    addTearDown(fake.dispose);
    expect(fake.read(translationClockProvider)(), 123);
  });
}
