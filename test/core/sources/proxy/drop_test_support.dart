import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/core/sources/source_plugin_records.dart';

/// An enabled source plugin record with id [id].
LyricsPluginRecord sourceRecord(String id) => LyricsPluginRecord(
  kind: PluginKind.source,
  installId: id,
  name: 'Plugin $id',
  version: 1,
  apiVersion: 1,
  hosts: const ['*.example.com'],
  config: const [],
  packageDir: '$id/v1-1',
  sourceKind: LyricsPluginSourceKind.file,
  sourceName: 'x.zip',
  installedAt: 5,
  updatedAt: 5,
);

/// What `sourcePluginRecordsProvider` gives in these tests.
class TestRecords extends Notifier<AsyncValue<List<LyricsPluginRecord>>> {
  TestRecords(this._initial);

  final AsyncValue<List<LyricsPluginRecord>> _initial;

  @override
  AsyncValue<List<LyricsPluginRecord>> build() => _initial;

  void set(AsyncValue<List<LyricsPluginRecord>> value) => state = value;

  void ids(List<String> ids) =>
      state = AsyncValue.data([for (final id in ids) sourceRecord(id)]);
}

/// Settings held in memory; nothing is written.
class TestSettings extends SettingsNotifier {
  TestSettings(this._initial);

  final AppSettings _initial;

  @override
  AppSettings build() => _initial;

  void set(AppSettings value) => state = value;

  void consent(Set<String> ids) => state = state.copyWith(
    onlineSources: OnlineSourcesPrefs(noticeAcknowledged: ids),
  );
}

/// Records and settings a test can change, and the overrides that put them
/// in a container.
class DropTestState {
  DropTestState({
    AsyncValue<List<LyricsPluginRecord>>? records,
    this._consented = const {},
  }) : records =
           NotifierProvider<TestRecords, AsyncValue<List<LyricsPluginRecord>>>(
             () => TestRecords(records ?? const AsyncValue.data([])),
           );

  final NotifierProvider<TestRecords, AsyncValue<List<LyricsPluginRecord>>>
  records;
  final Set<String> _consented;

  List<Override> get overrides => [
    sourcePluginRecordsProvider.overrideWith((ref) => ref.watch(records)),
    settingsProvider.overrideWith(
      () => TestSettings(
        AppSettings(
          onlineSources: OnlineSourcesPrefs(noticeAcknowledged: _consented),
        ),
      ),
    ),
  ];

  TestRecords recordsOf(ProviderContainer c) => c.read(records.notifier);

  TestSettings settingsOf(ProviderContainer c) =>
      c.read(settingsProvider.notifier) as TestSettings;
}
