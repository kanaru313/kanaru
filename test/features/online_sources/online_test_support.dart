import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart' show Fake;
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/core/sources/source_plugin_records.dart';
import 'package:kanaru/core/sources/source_plugin_runner.dart';

/// Id of the test source plugin.
const sourceId = 'plugin-aaaaaaaaaaaa';

/// An enabled source plugin record.
LyricsPluginRecord sourceRecord({
  String id = sourceId,
  String name = 'Tube',
  List<String> hosts = const ['*.example.com', 'api.example.com', 'b.test'],
}) => LyricsPluginRecord(
  kind: PluginKind.source,
  installId: id,
  name: name,
  version: 1,
  apiVersion: 1,
  hosts: hosts,
  config: const [],
  packageDir: '$id/v1-1',
  sourceKind: LyricsPluginSourceKind.file,
  sourceName: 'x.zip',
  installedAt: 5,
  updatedAt: 5,
);

/// What `sourcePluginRecordsProvider` gives; a test changes it with [set].
class TestRecords extends Notifier<AsyncValue<List<LyricsPluginRecord>>> {
  TestRecords(this._initial);

  final AsyncValue<List<LyricsPluginRecord>> _initial;

  @override
  AsyncValue<List<LyricsPluginRecord>> build() => _initial;

  void set(AsyncValue<List<LyricsPluginRecord>> value) => state = value;
}

/// Settings held in memory; nothing is written.
class TestSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

typedef RecordsProvider =
    NotifierProvider<TestRecords, AsyncValue<List<LyricsPluginRecord>>>;

/// A provider holding [initial]; read its notifier to change the records.
RecordsProvider testRecords(AsyncValue<List<LyricsPluginRecord>> initial) =>
    NotifierProvider(() => TestRecords(initial));

/// Overrides that give [records] to the app and keep settings in memory.
List<Override> onlineOverrides(RecordsProvider records) => [
  sourcePluginRecordsProvider.overrideWith((ref) => ref.watch(records)),
  settingsProvider.overrideWith(TestSettings.new),
];

/// A runner that answers searches with [onSearch] and records them.
class FakeSourceRunner extends Fake implements SourcePluginRunner {
  FakeSourceRunner(this.onSearch);

  final Future<SourceSearchPage> Function(
    String installId,
    String query,
    bool Function()? abandoned,
  )
  onSearch;

  /// `<installId>|<query>` of every search, in order.
  final searches = <String>[];

  @override
  Future<SourceSearchPage> search(
    String installId,
    String query, {
    String? next,
    bool Function()? abandoned,
  }) {
    searches.add('$installId|$query');
    return onSearch(installId, query, abandoned);
  }
}

/// A page of [count] results titled `Song 1`…, by `Artist n`.
SourceSearchPage pageOf(int count) => SourceSearchPage(
  items: [
    for (var i = 1; i <= count; i++)
      SourceItem(
        id: 'id$i',
        title: 'Song $i',
        artist: 'Artist $i',
        duration: Duration(minutes: i, seconds: 5),
      ),
  ],
);
