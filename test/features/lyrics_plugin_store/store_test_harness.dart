import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_catalog.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/features/lyrics_plugin_store/plugin_store_providers.dart';
import 'package:kanaru/l10n/l10n.dart';

const repoA = 'https://a.example.com/plugins.json';
const repoB = 'https://b.example.com/plugins.json';

/// The strings of the English locale.
AppLocalizations get en => lookupAppLocalizations(const Locale('en'));

/// The strings of the Vietnamese locale.
AppLocalizations get vi => lookupAppLocalizations(const Locale('vi'));

PluginCatalogEntry entryOf(
  String slug, {
  String? name,
  int version = 3,
  int apiVersion = 1,
  List<String> hosts = const ['music.example.com'],
  String author = 'someone',
  String description = '',
}) => PluginCatalogEntry(
  slug: slug,
  name: name ?? slug,
  version: version,
  apiVersion: apiVersion,
  hosts: hosts,
  path: Uri.parse('https://a.example.com/$slug.zip'),
  author: author,
  description: description,
);

PluginRepo repoOf(
  String url,
  String name, {
  List<PluginCatalogEntry> entries = const [],
  RepoLoadError? error,
}) => PluginRepo(
  url: url,
  name: name,
  author: '',
  addedAt: 1,
  error: error,
  catalog: PluginCatalog(name: name, author: '', entries: entries, dropped: 0),
  kind: RepoAddressKind.public,
);

LyricsPluginRecord recordOf(
  String id, {
  String name = 'Demo',
  int version = 3,
  String? repoUrl,
  String? repoSlug,
  String sourceName = 'demo.zip',
  String? author,
}) => LyricsPluginRecord(
  installId: id,
  name: name,
  author: author,
  version: version,
  apiVersion: 1,
  hosts: const ['music.example.com'],
  config: const [],
  packageDir: '$id/v$version-1',
  sourceKind: repoUrl == null
      ? LyricsPluginSourceKind.file
      : LyricsPluginSourceKind.repo,
  sourceName: sourceName,
  repoUrl: repoUrl,
  repoSlug: repoSlug,
  installedAt: 1000,
  updatedAt: 1000,
);

/// A repos controller that records what the screens ask of it and answers
/// with the results the test sets.
class FakeRepos extends Fake implements LyricsPluginReposController {
  int refreshAllCalls = 0;
  final refreshed = <String>[];
  final installs = <(String, String)>[];
  final updates = <String>[];
  int updateAllCalls = 0;
  final removed = <String>[];
  final adds = <String>[];

  RepoPluginResult installResult = RepoPluginDone(
    recordOf('plugin-new'),
    RepoPluginChange.installed,
  );
  RepoPluginResult updateResult = RepoPluginDone(
    recordOf('plugin-new', version: 4),
    RepoPluginChange.updated,
  );
  List<RepoUpdateOutcome> updateAllResult = const [];
  AddRepoResult addResult = const AddRepoAdded(
    url: repoA,
    name: 'Kho',
    pluginCount: 4,
  );

  /// When set, `install` waits for it.
  Completer<void>? installGate;

  /// When set, `add` waits for it.
  Completer<void>? addGate;

  /// When set, `updateAll` waits for it.
  Completer<void>? updateAllGate;

  /// When set, `install` throws it.
  Object? installError;

  /// What `watchRepos` answers (the stored catalogs). `pumpStore` fills it
  /// with its `repos` when null; `onRefresh` may change it, as a real refresh
  /// stores a new catalog.
  List<PluginRepo>? catalog;

  /// Runs on each `refresh(url)`, before it returns.
  void Function(String url)? onRefresh;
  Set<String> _updating = {};
  final _changes = StreamController<Set<String>>.broadcast();

  void setUpdating(Set<String> ids) {
    _updating = ids;
    _changes.add(ids);
  }

  @override
  Set<String> get updating => _updating;

  @override
  Stream<Set<String>> get updatingChanges => _changes.stream;

  @override
  Stream<List<PluginRepo>> watchRepos() =>
      Stream.value(catalog ?? const <PluginRepo>[]);

  @override
  Future<List<RepoRefreshResult>> refreshAll() async {
    refreshAllCalls++;
    return const [];
  }

  @override
  Future<RepoRefreshResult?> refresh(String url) async {
    refreshed.add(url);
    onRefresh?.call(url);
    return null;
  }

  @override
  Future<RepoPluginResult> install(String repoUrl, String slug) async {
    installs.add((repoUrl, slug));
    await installGate?.future;
    if (installError != null) throw installError!;
    return installResult;
  }

  @override
  Future<RepoPluginResult> update(String installId) async {
    updates.add(installId);
    return updateResult;
  }

  @override
  Future<List<RepoUpdateOutcome>> updateAll() async {
    updateAllCalls++;
    await updateAllGate?.future;
    return updateAllResult;
  }

  @override
  Future<bool> remove(String url) async {
    removed.add(url);
    return true;
  }

  @override
  Future<AddRepoResult> add(String input) async {
    adds.add(input);
    await addGate?.future;
    return addResult;
  }
}

/// A plugins controller that records uninstalls, undos and file installs.
class FakePlugins extends Fake implements LyricsPluginsController {
  final uninstalls = <String>[];
  final undos = <String>[];
  final files = <String>[];
  PluginInstallOutcome fileResult = PluginInstalled(recordOf('plugin-file'));
  LyricsPluginUninstall uninstallResult = LyricsPluginUninstall.deleted;
  LyricsPluginUninstall undoResult = LyricsPluginUninstall.deleted;

  @override
  Future<LyricsPluginUninstall> uninstall(String installId) async {
    uninstalls.add(installId);
    return uninstallResult;
  }

  @override
  Future<LyricsPluginUninstall> undoInstall(String installId) async {
    undos.add(installId);
    return undoResult;
  }

  @override
  Future<PluginInstallOutcome> installFromFile(String path) async {
    files.add(path);
    return fileResult;
  }
}

/// The records the store sees in tests; change them with
/// `storeRecordsOf(tester).set(...)` to act like the library changing.
class StoreTestRecords extends Notifier<List<LyricsPluginRecord>> {
  StoreTestRecords(this._initial);

  final List<LyricsPluginRecord> _initial;

  @override
  List<LyricsPluginRecord> build() => _initial;

  void set(List<LyricsPluginRecord> records) => state = records;
}

final storeTestRecordsProvider =
    NotifierProvider<StoreTestRecords, List<LyricsPluginRecord>>(
      () => throw UnimplementedError('overridden by pumpStore'),
    );

/// The notifier behind the records a [pumpStore] page shows.
StoreTestRecords storeRecordsOf(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  return container.read(storeTestRecordsProvider.notifier);
}

/// Pumps [page] in an app with the English strings and the fakes wired in.
/// With [available] false there is no controller, as without a library.
Future<void> pumpStore(
  WidgetTester tester,
  Widget page, {
  List<LyricsPluginRecord> records = const [],
  List<PluginRepo> repos = const [],
  FakeRepos? reposController,
  FakePlugins? plugins,
  bool available = true,
  String? pickedFile,
  Locale locale = const Locale('en'),
  Size size = const Size(1000, 1600),
  List<Override> overrides = const [],
}) async {
  final fakeRepos = reposController ?? FakeRepos();
  fakeRepos.catalog ??= repos;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storeTestRecordsProvider.overrideWith(() => StoreTestRecords(records)),
        pluginStoreRawInputProvider.overrideWith(
          (ref) => AsyncData(
            PluginStoreInput(
              records: ref.watch(storeTestRecordsProvider),
              repos: repos,
              available: available,
            ),
          ),
        ),
        lyricsPluginReposProvider.overrideWith((ref) => Stream.value(repos)),
        lyricsPluginReposControllerProvider.overrideWithValue(
          available ? fakeRepos : null,
        ),
        lyricsPluginsControllerProvider.overrideWithValue(
          available ? (plugins ?? FakePlugins()) : null,
        ),
        pluginZipPickerProvider.overrideWithValue(() async => pickedFile),
        ...overrides,
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: page),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
