import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_catalog.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_repo.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_store_view.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';

const urlA = 'https://a.example.com/plugins.json';
const urlB = 'https://b.example.com/plugins.json';

PluginCatalogEntry entry(
  String slug, {
  String? name,
  int version = 1,
  int apiVersion = 1,
  List<String> hosts = const ['host.example.com'],
  String author = '',
  Uri? icon,
}) => PluginCatalogEntry(
  slug: slug,
  name: name ?? slug,
  version: version,
  apiVersion: apiVersion,
  hosts: hosts,
  path: Uri.parse('https://a.example.com/$slug.zip'),
  author: author,
  icon: icon,
);

PluginRepo repo(
  String url,
  String name,
  List<PluginCatalogEntry> entries, {
  RepoLoadError? error,
}) => PluginRepo(
  url: url,
  name: name,
  author: '',
  addedAt: 1,
  error: error,
  kind: RepoAddressKind.public,
  catalog: PluginCatalog(name: name, author: '', entries: entries, dropped: 0),
);

LyricsPluginRecord record(
  String id,
  String name, {
  int version = 1,
  String? repoUrl,
  String? slug,
  String sourceName = 'x.zip',
  bool removed = false,
  String? author,
  List<String> hosts = const ['host.example.com'],
}) => LyricsPluginRecord(
  installId: id,
  name: name,
  author: author,
  version: version,
  apiVersion: 1,
  hosts: hosts,
  config: const [],
  packageDir: '$id/v1-1',
  sourceKind: repoUrl == null
      ? LyricsPluginSourceKind.file
      : LyricsPluginSourceKind.repo,
  sourceName: sourceName,
  repoUrl: repoUrl,
  repoSlug: slug,
  installedAt: 1,
  updatedAt: 1,
  removedAt: removed ? 5 : null,
);

List<String> names(List<StoreRow> rows) => [for (final r in rows) r.name];

PluginStoreView view(
  List<LyricsPluginRecord> records,
  List<PluginRepo> repos, {
  String search = '',
  StoreSourceFilter filter = const StoreSourceFilter.all(),
}) => buildPluginStoreView(
  PluginStoreInput(
    records: records,
    repos: repos,
    search: search,
    filter: filter,
  ),
);

void main() {
  final repos = [
    repo(urlA, 'Alpha Repo', [
      entry('one', name: 'One', version: 2),
      entry('two', name: 'Two'),
      entry('three', name: 'Three', author: 'Zed', hosts: ['lyrics.zed.org']),
      entry('future', name: 'Future', apiVersion: 2),
    ]),
    repo(urlB, 'Beta Repo', [entry('one', name: 'One')]),
  ];

  test('sections: updates, installed, not installed, hidden count', () {
    final records = [
      record('p1', 'One', repoUrl: urlA, slug: 'one'),
      record('p2', 'Two', repoUrl: urlA, slug: 'two'),
      record('p3', 'Mine', sourceName: 'mine.zip'),
    ];
    final v = view(records, repos);
    expect(names(v.updates), ['One']);
    expect(v.updates.single.record!.installId, 'p1');
    expect(v.updates.single.entry!.version, 2);
    expect(names(v.installed), ['Two', 'Mine']);
    expect(v.installed.last.isFromFile, isTrue);
    expect(v.installed.last.repoName, isNull);
    expect(names(v.notInstalled), ['Three', 'One']);
    expect(v.notInstalled.last.repoName, 'Beta Repo');
    expect(v.needsNewerApp, 1);
    expect(v.hasFileSource, isTrue);
    expect(v.showSourceChips, isTrue);
    expect(v.isEmpty, isFalse);
  });

  test('installed is by (repo url, slug): same slug in another repo shows', () {
    final v = view([
      record('p1', 'One', repoUrl: urlA, slug: 'one', version: 2),
    ], repos);
    expect(names(v.installed), ['One']);
    expect(v.notInstalled.map((r) => r.repoUrl), contains(urlB));
    expect(
      v.notInstalled.where((r) => r.repoUrl == urlA && r.entry!.slug == 'one'),
      isEmpty,
    );
  });

  test('a newer catalog entry that needs a newer app is no update', () {
    final r = [
      repo(urlA, 'A', [entry('one', version: 9, apiVersion: 2)]),
    ];
    final v = view([record('p1', 'One', repoUrl: urlA, slug: 'one')], r);
    expect(v.updates, isEmpty);
    expect(names(v.installed), ['One']);
    expect(v.needsNewerApp, 0, reason: 'installed entries are not counted');
  });

  test('file plugins never update, even with a matching catalog name', () {
    final v = view([record('p1', 'One')], repos);
    expect(v.updates, isEmpty);
    expect(names(v.installed), ['One']);
  });

  test(
    'a removed record is not installed; its entry is under not installed',
    () {
      final v = view([
        record('p1', 'One', repoUrl: urlA, slug: 'one', removed: true),
      ], repos);
      expect(v.installed, isEmpty);
      expect(
        v.notInstalled.where((r) => r.repoUrl == urlA && r.name == 'One'),
        hasLength(1),
      );
      expect(v.hasFileSource, isFalse);
    },
  );

  test(
    'a plugin whose repo was removed stays installed with its stored name',
    () {
      final v = view([
        record(
          'p1',
          'Old',
          repoUrl: 'https://gone.example.com/x',
          slug: 'old',
          sourceName: 'Gone Repo',
        ),
      ], repos);
      expect(v.updates, isEmpty);
      final row = v.installed.single;
      expect(row.repoName, 'Gone Repo');
      expect(row.entry, isNull);
      expect(row.isFromFile, isFalse);
    },
  );

  test('search matches name, author, repo name and host', () {
    final records = [
      record(
        'p3',
        'Mine',
        author: 'Quinn',
        sourceName: 'mine.zip',
        hosts: ['quinn.example.net'],
      ),
    ];
    expect(names(view(records, repos, search: 'THREE').notInstalled), [
      'Three',
    ]);
    expect(names(view(records, repos, search: 'zed').notInstalled), ['Three']);
    expect(names(view(records, repos, search: 'zed.org').notInstalled), [
      'Three',
    ]);
    expect(names(view(records, repos, search: 'beta').notInstalled), ['One']);
    expect(names(view(records, repos, search: 'quinn').installed), ['Mine']);
    expect(names(view(records, repos, search: 'quinn.example').installed), [
      'Mine',
    ]);
    expect(view(records, repos, search: 'nothing').isEmpty, isTrue);
    expect(view(records, repos, search: ' ').isEmpty, isFalse);
  });

  test('search and filter also apply to the hidden count', () {
    expect(view([], repos, search: 'future').needsNewerApp, 1);
    expect(view([], repos, search: 'one').needsNewerApp, 0);
    expect(
      view([], repos, filter: const StoreSourceFilter.repo(urlB)).needsNewerApp,
      0,
    );
  });

  test('source filter: one repo, from file, all', () {
    final records = [
      record('p1', 'Two', repoUrl: urlA, slug: 'two'),
      record('p3', 'Mine'),
      record('p4', 'Gone', repoUrl: 'https://gone.example.com/x', slug: 'g'),
    ];
    final a = view(records, repos, filter: const StoreSourceFilter.repo(urlA));
    expect(names(a.installed), ['Two']);
    expect(names(a.notInstalled), ['One', 'Three']);
    final b = view(records, repos, filter: const StoreSourceFilter.repo(urlB));
    expect(b.installed, isEmpty);
    expect(names(b.notInstalled), ['One']);
    final file = view(
      records,
      repos,
      filter: const StoreSourceFilter.fromFile(),
    );
    expect(names(file.installed), ['Mine']);
    expect(file.notInstalled, isEmpty);
    expect(names(view(records, repos).installed), ['Two', 'Mine', 'Gone']);
  });

  test('failing repos are listed and their plugins still shown', () {
    const error = RepoLoadError(RepoFetchErrorKind.network);
    final r = [
      repo(urlA, 'Alpha Repo', [entry('one')], error: error),
      repo(urlB, 'Beta Repo', [entry('two')]),
    ];
    final v = view([], r);
    expect(v.failingRepos.single.name, 'Alpha Repo');
    expect(v.failingRepos.single.url, urlA);
    expect(v.failingRepos.single.error, error);
    expect(names(v.notInstalled), ['one', 'two']);
    expect(
      view([], r, filter: const StoreSourceFilter.repo(urlB)).failingRepos,
      hasLength(1),
      reason: 'the banner does not depend on the filter',
    );
  });

  test('a repo that was never fetched lists nothing', () {
    const never = PluginRepo(url: urlA, name: 'N', author: '', addedAt: 1);
    final v = view([], [never]);
    expect(v.isEmpty, isTrue);
    expect(v.showSourceChips, isFalse);
  });

  test('catalog icon and chips', () {
    final icon = Uri.parse('https://a.example.com/i.png');
    final v = view([], [
      repo(urlA, 'A', [entry('one', icon: icon)]),
    ]);
    expect(v.notInstalled.single.catalogIcon, icon);
    expect(v.showSourceChips, isFalse);
    expect(v.sources.single.url, urlA);
  });

  test('source filters are values', () {
    expect(const StoreSourceFilter.all(), const StoreSourceFilter.all());
    expect(
      const StoreSourceFilter.repo(urlA),
      const StoreSourceFilter.repo(urlA),
    );
    expect(
      const StoreSourceFilter.repo(urlA).hashCode,
      const StoreSourceFilter.repo(urlA).hashCode,
    );
    expect(
      const StoreSourceFilter.repo(urlA) == const StoreSourceFilter.repo(urlB),
      isFalse,
    );
    expect(
      const StoreSourceFilter.fromFile() == const StoreSourceFilter.all(),
      isFalse,
    );
    expect(
      const StoreSourceFilter.fromFile(),
      const StoreSourceFilter.fromFile(),
    );
  });

  test('an unavailable feature is told apart from an empty store', () {
    final empty = buildPluginStoreView(
      const PluginStoreInput(records: [], repos: []),
    );
    final unavailable = buildPluginStoreView(
      const PluginStoreInput(records: [], repos: [], available: false),
    );
    expect(empty.isEmpty && empty.available, isTrue);
    expect(unavailable.isEmpty, isTrue);
    expect(unavailable.available, isFalse);
  });
}
