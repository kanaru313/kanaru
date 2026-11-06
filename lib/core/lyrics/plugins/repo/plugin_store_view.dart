import '../../../database/lyrics_plugin_spec.dart';
import '../lyrics_plugin_record.dart';
import '../package/plugin_manifest_parser.dart' show supportedPluginApiVersion;
import 'plugin_catalog.dart';
import 'plugin_repo.dart';
import 'plugin_store_facets.dart';
import 'plugin_store_filters.dart';
import 'plugin_store_rows.dart';
import 'plugin_update_check.dart';

export 'plugin_store_facets.dart';
export 'plugin_store_filters.dart';
export 'plugin_store_rows.dart';

/// What the store view is computed from.
class PluginStoreInput {
  const PluginStoreInput({
    required this.records,
    required this.repos,
    this.search = '',
    this.filters = const PluginStoreFilters(),
    this.installedLanguages = const {},
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

  /// The picked filter values; a record of a kind this build does not know is
  /// never listed.
  final PluginStoreFilters filters;

  /// Language keys read from installed packages, by install id. Used for a
  /// plugin whose catalog entry declares none (or has no entry).
  final Map<String, List<String>> installedLanguages;
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
    required this.facets,
    required this.filters,
    required this.showKindTag,
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

  /// The added repositories, in the order the source filter lists them.
  final List<PluginRepo> sources;
  final bool hasFileSource;

  /// The filter groups with their values and counts, in modal order.
  final List<StoreFacetGroup> facets;

  /// The picked filter values behind this view.
  final PluginStoreFilters filters;

  /// Rows listed, in all sections.
  int get shownCount => updates.length + installed.length + notInstalled.length;

  /// Rows show their kind when the rows that pass the filters (counted
  /// before the search text, so tags do not flicker while typing) are of
  /// more than one kind.
  final bool showKindTag;

  /// At least one group is worth showing, so the filter button is too.
  bool get hasFilters => facets.any((g) => g.visible);

  bool get isEmpty =>
      updates.isEmpty && installed.isEmpty && notInstalled.isEmpty;
}

/// Builds the store list; a pure function of [input].
PluginStoreView buildPluginStoreView(PluginStoreInput input) {
  final repos = {for (final r in input.repos) r.url: r};
  final live = [
    for (final r in input.records)
      if (!r.isRemoved && r.kind != null) r,
  ];
  final installedKeys = {
    for (final r in input.records)
      if (!r.isRemoved && r.repoUrl != null) _key(r.repoUrl!, r.repoSlug!),
  };
  final query = input.search.trim().toLowerCase();

  final updates = <StoreRow>[];
  final installed = <StoreRow>[];
  for (final record in live) {
    final update = availableUpdate(record, repos);
    final repo = repos[record.repoUrl];
    final entry = update ?? repo?.entry(record.repoSlug ?? '');
    final row = StoreRow(
      name: record.name,
      author: record.author ?? '',
      hosts: record.hosts,
      record: record,
      entry: entry,
      repoUrl: record.repoUrl,
      repoName:
          repo?.name ?? (record.repoUrl == null ? null : record.sourceName),
      languages: (entry?.languages.isNotEmpty ?? false)
          ? entry!.languages
          : input.installedLanguages[record.installId] ?? const [],
    );
    (update != null ? updates : installed).add(row);
  }

  final notInstalled = <StoreRow>[];
  final needsNewer = <StoreRow>[];
  for (final repo in input.repos) {
    for (final entry in repo.catalog?.entries ?? const <PluginCatalogEntry>[]) {
      if (installedKeys.contains(_key(repo.url, entry.slug))) continue;
      final row = StoreRow(
        name: entry.name,
        author: entry.author,
        hosts: entry.hosts,
        entry: entry,
        repoUrl: repo.url,
        repoName: repo.name,
        languages: entry.languages,
      );
      (entry.apiVersion > supportedPluginApiVersion ? needsNewer : notInstalled)
          .add(row);
    }
  }

  bool searched(StoreRow row) => _matches(row, query);
  bool shown(StoreRow row) =>
      searched(row) && input.filters.matches(storeRowFacetKeys(row));
  final kinds = {
    for (final row in [...updates, ...installed, ...notInstalled])
      if (input.filters.matches(storeRowFacetKeys(row))) row.kind,
  };
  final facets = computeStoreFacets(
    [...updates, ...installed, ...notInstalled],
    input.filters,
    searched,
    repoOrder: [for (final r in input.repos) r.url],
  );

  return PluginStoreView(
    updates: List.unmodifiable(updates.where(shown)),
    installed: List.unmodifiable(installed.where(shown)),
    notInstalled: List.unmodifiable(notInstalled.where(shown)),
    needsNewerApp: needsNewer.where(shown).length,
    failingRepos: [
      for (final repo in input.repos)
        if (repo.error != null) FailingRepo(repo.url, repo.name, repo.error!),
    ],
    sources: List.unmodifiable(input.repos),
    hasFileSource: live.any((r) => r.sourceKind == LyricsPluginSourceKind.file),
    facets: facets,
    filters: input.filters,
    showKindTag: kinds.length > 1,
    available: input.available,
  );
}

String _key(String url, String slug) => '$url\n$slug';

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
