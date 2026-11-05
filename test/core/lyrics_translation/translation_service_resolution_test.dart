import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/lyrics_translation/translation_service_resolution.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_plugin_runner.dart';
import 'fake_translator.dart';

final _plugin = TranslationServiceId.tryParse('plugin-abc123def456')!;
final _other = TranslationServiceId.tryParse('plugin-zzzzzzzzzzzz')!;

AppSettings _settings(
  TranslationServiceId? service,
  Set<TranslationServiceId> acknowledged, {
  bool show = true,
}) => AppSettings(
  translation: TranslationPrefs(
    show: show,
    service: service,
    noticeAcknowledged: acknowledged,
  ),
);

class _RecordsNotifier extends Notifier<AsyncValue<List<LyricsPluginRecord>>> {
  @override
  AsyncValue<List<LyricsPluginRecord>> build() => const AsyncValue.loading();

  void set(AsyncValue<List<LyricsPluginRecord>> value) => state = value;
}

final _newRecords =
    NotifierProvider<_RecordsNotifier, AsyncValue<List<LyricsPluginRecord>>>(
      _RecordsNotifier.new,
    );

void main() {
  late Directory root;
  late LibraryDatabase db;

  setUp(() {
    root = Directory.systemTemp.createTempSync('kanaru_resolution_');
    db = memoryDb();
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  ProviderContainer make(
    AppSettings settings,
    AsyncValue<List<LyricsPluginRecord>> records, {
    bool withDb = true,
  }) {
    final container = ProviderContainer(
      overrides: <Override>[
        settingsFileProvider.overrideWithValue(
          SettingsFile('${root.path}/settings.json'),
        ),
        initialSettingsProvider.overrideWithValue(settings),
        libraryDatabaseProvider.overrideWithValue(withDb ? db : null),
        translatePluginRecordsProvider.overrideWithValue(records),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  AsyncValue<List<LyricsPluginRecord>> live(List<String> ids) =>
      AsyncValue.data([for (final id in ids) translateRecord(id)]);

  group('effectiveTranslationServiceProvider', () {
    test('stored null resolves to null', () {
      final c = make(_settings(null, {}), live([]));
      expect(c.read(effectiveTranslationServiceProvider), isNull);
    });

    test('two plugins installed and the default removed resolves to null', () {
      final c = make(_settings(null, {}), live([_plugin.value, _other.value]));
      expect(c.read(effectiveTranslationServiceProvider), isNull);
    });

    test('loading, failed or no database: unavailable', () {
      for (final records in [
        const AsyncValue<List<LyricsPluginRecord>>.loading(),
        AsyncValue<List<LyricsPluginRecord>>.error(
          StateError('x'),
          StackTrace.empty,
        ),
      ]) {
        final c = make(_settings(_plugin, {_plugin}), records);
        expect(c.read(effectiveTranslationServiceProvider), isNull);
      }
    });

    test('a live translate plugin is itself', () {
      final c = make(_settings(_plugin, {_plugin}), live([_plugin.value]));
      expect(c.read(effectiveTranslationServiceProvider), _plugin);
    });

    test('a plugin that is gone, or another one is installed: null', () {
      final c = make(_settings(_plugin, {_plugin}), live([_other.value]));
      expect(c.read(effectiveTranslationServiceProvider), isNull);
      final empty = make(_settings(_plugin, {_plugin}), live([]));
      expect(empty.read(effectiveTranslationServiceProvider), isNull);
    });

    test('it never writes the settings', () {
      final c = make(_settings(_plugin, {_plugin}), live([]));
      c.read(effectiveTranslationServiceProvider);
      expect(c.read(settingsProvider).translation.service, _plugin);
    });

    test('needsNoticeFor asks about the id it is given', () {
      final prefs = _settings(_plugin, {_plugin}).translation;
      expect(needsNoticeFor(prefs, _plugin), isFalse);
      expect(needsNoticeFor(prefs, _other), isTrue);
    });
  });

  group('translationServiceSweepProvider', () {
    Future<void> sweep(ProviderContainer c) async {
      c.listen(translationServiceSweepProvider, (_, _) {});
      await settle();
    }

    test('a dead selected plugin becomes null and off, its ack is dropped', () async {
      final c = make(
        _settings(_plugin, {_plugin, _other}),
        live([_other.value]),
      );
      await sweep(c);

      final prefs = c.read(settingsProvider).translation;
      expect(prefs.service, isNull);
      expect(prefs.noticeAcknowledged, {_other});
      expect(prefs.show, isFalse);
    });

    test('show goes off and service becomes null when plugin is uninstalled', () async {
      final c = make(_settings(_plugin, {_plugin}), live([]));
      await sweep(c);

      final prefs = c.read(settingsProvider).translation;
      expect(prefs.service, isNull);
      expect(prefs.noticeAcknowledged, isEmpty);
      expect(prefs.show, isFalse);
    });

    test(
      'a restart after the sweep keeps translation off with null service',
      () async {
        final c = make(_settings(_plugin, {_plugin, _other}), live([_other.value]));
        await sweep(c);
        await c.read(settingsProvider.notifier).flush();

        final stored = jsonDecode(
          File('${root.path}/settings.json').readAsStringSync(),
        ) as Map<String, Object?>;
        final json = stored['lyricsTranslation'] as Map<String, Object?>;
        expect(json['service'], isNull);
        expect(json['show'], isFalse);
        expect(json['noticeAcknowledged'], [_other.value]);
      },
    );

    test('no write while loading, on error or without a database', () async {
      final start = _settings(_plugin, {_plugin});
      final cases = [
        make(start, const AsyncValue.loading()),
        make(start, AsyncValue.error(StateError('x'), StackTrace.empty)),
        make(start, live([]), withDb: false),
      ];
      for (final c in cases) {
        await sweep(c);
        expect(c.read(settingsProvider), start);
      }
    });

    test('a live plugin is left alone', () async {
      final start = _settings(_plugin, {_plugin});
      final c = make(start, live([_plugin.value]));
      await sweep(c);
      expect(c.read(settingsProvider), start);
    });

    test('records arriving later, then an uninstall: one write each', () async {
      final records = _newRecords;
      final c = ProviderContainer(
        overrides: <Override>[
          settingsFileProvider.overrideWithValue(
            SettingsFile('${root.path}/settings.json'),
          ),
          initialSettingsProvider.overrideWithValue(
            _settings(_plugin, {_plugin}),
          ),
          libraryDatabaseProvider.overrideWithValue(db),
          translatePluginRecordsProvider.overrideWith(
            (ref) => ref.watch(records),
          ),
        ],
      );
      addTearDown(c.dispose);
      var writes = 0;
      c.listen(settingsProvider, (_, _) => writes++);
      c.read(records.notifier).set(const AsyncValue.loading());
      await sweep(c);
      expect(writes, 0);

      c.read(records.notifier).set(live([_plugin.value]));
      await settle();
      expect(writes, 0);
      expect(c.read(settingsProvider).translation.service, _plugin);

      c.read(records.notifier).set(live([]));
      await settle();
      expect(writes, 1);
      expect(c.read(settingsProvider).translation.service, isNull);
      expect(c.read(settingsProvider).translation.show, isFalse);
      await settle();
      expect(writes, 1);
    });
  });
}
