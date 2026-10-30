import '../../../database/lyrics_plugin_spec.dart';
import '../lyrics_plugin_record.dart';
import '../package/plugin_manifest_parser.dart' show supportedPluginApiVersion;
import 'plugin_catalog.dart';
import 'plugin_repo.dart';
import 'plugin_store_rows.dart';
import 'plugin_update_check.dart';

export 'plugin_store_rows.dart';

/// What the store view is computed from.
class PluginStoreInput {
  const PluginStoreInput({
    required this.records,
    required this.repos,
    this.search = '',
    this.filter = const StoreSourceFilter.all(),
    this.available = true,
  });

  /// False while the plugin feature is unavailable (no library database or
  /// data folder): records and repos are then empty because nothing can be
  /// read, not because there is nothing, and adding a repository cannot work.
  final bool available;

  /// Every record, removed ones included.
  final List<LyricsPluginRecord> records;
  final List<PluginRepo> repos;
  final String search;
  final StoreSourceFilter filter;
}

/// The store list, ready to show. Empty sections are empty lists; the UI
/// hides them.
class PluginStoreView {
  const PluginStoreView({
    required this.updates,
    required this.installed,
    required this.notInstalled,
    required this.needsNewerApp,
    required this.failingRepos,
    required this.sources,
    required this.hasFileSource,
    this.available = true,
  });

  /// Copied from [PluginStoreInput.available]: when false, show "plugins
  /// unavailable" instead of the empty store.
  final bool available;

  /// Repo plugins with a newer catalog version this app can run.
  final List<StoreRow> updates;

  /// Installed plugins with no update: from a repo or from a file.
  final List<StoreRow> installed;

  /// Catalog entries not installed. An entry whose record was removed is
  /// here, and installing it brings the old install id back.
  final List<StoreRow> notInstalled;

  /// Entries hidden because they need a newer Kanaru (after search and
  /// filter).
  final int needsNewerApp;

  /// Repositories whose last fetch failed, in repo order. Their plugins are
  /// still listed from the last good catalog.
  final List<FailingRepo> failingRepos;

  /// The added repositories, for the source chips.
  final List<PluginRepo> sources;
  final bool hasFileSource;

  /// The chips are worth showing from two sources on.
  bool get showSourceChips => sources.length + (hasFileSource ? 1 : 0) >= 2;

  bool get isEmpty =>
      updates.isEmpty && installed.isEmpty && notInstalled.isEmpty;
}

/// Builds the store list; a pure function of [input].
PluginStoreView buildPluginStoreView(PluginStoreInput input) {
  final repos = {for (final r in input.repos) r.url: r};
  final live = [
    for (final r in input.records)
      if (!r.isRemoved) r,
  ];
  final installedKeys = {
    for (final r in live)
      if (r.repoUrl != null) _key(r.repoUrl!, r.repoSlug!),
  };
  final query = input.search.trim().toLowerCase();

  final updates = <StoreRow>[];
  final installed = <StoreRow>[];
  for (final record in live) {
    final update = availableUpdate(record, repos);
    final repo = repos[record.repoUrl];
    final row = StoreRow(
      name: record.name,
      author: record.author ?? '',
      hosts: record.hosts,
      record: record,
      entry: update ?? repo?.entry(record.repoSlug ?? ''),
      repoUrl: record.repoUrl,
      repoName:
          repo?.name ?? (record.repoUrl == null ? null : record.sourceName),
    );
    if (!_inFilter(input.filter, record.repoUrl) || !_matches(row, query)) {
      continue;
    }
    (update != null ? updates : installed).add(row);
  }

  final notInstalled = <StoreRow>[];
  var needsNewerApp = 0;
  for (final repo in input.repos) {
    if (!_inFilter(input.filter, repo.url)) continue;
    for (final entry in repo.catalog?.entries ?? const <PluginCatalogEntry>[]) {
      if (installedKeys.contains(_key(repo.url, entry.slug))) continue;
      final row = StoreRow(
        name: entry.name,
        author: entry.author,
        hosts: entry.hosts,
        entry: entry,
        repoUrl: repo.url,
        repoName: repo.name,
      );
      if (!_matches(row, query)) continue;
      if (entry.apiVersion > supportedPluginApiVersion) {
        needsNewerApp++;
      } else {
        notInstalled.add(row);
      }
    }
  }

  return PluginStoreView(
    updates: List.unmodifiable(updates),
    installed: List.unmodifiable(installed),
    notInstalled: List.unmodifiable(notInstalled),
    needsNewerApp: needsNewerApp,
    failingRepos: [
      for (final repo in input.repos)
        if (repo.error != null) FailingRepo(repo.url, repo.name, repo.error!),
    ],
    sources: List.unmodifiable(input.repos),
    hasFileSource: live.any((r) => r.sourceKind == LyricsPluginSourceKind.file),
    available: input.available,
  );
}

String _key(String url, String slug) => '$url\n$slug';

/// [repoUrl] is the plugin's repository, null for a plugin from a file.
bool _inFilter(StoreSourceFilter filter, String? repoUrl) {
  if (filter.isAll) return true;
  if (filter.isFromFile) return repoUrl == null;
  return repoUrl == filter.repoUrl;
}

/// Name, author, repository name and host, case-insensitive.
bool _matches(StoreRow row, String query) {
  if (query.isEmpty) return true;
  return [
    row.name,
    row.author,
    row.repoName ?? '',
    ...row.hosts,
  ].any((field) => field.toLowerCase().contains(query));
}
