import 'package:drift/drift.dart';

// Lyrics source plugins: installed packages, source preferences, plugin
// repositories and per-plugin data. Times are epoch milliseconds, like the
// rest of the library database.
//
// Invariants (the contract for every writer and reader):
// 1. `lyrics_plugins.install_id` is the plugin's source id: the value in
//    `provider_id` of `online_lyrics`, `lyrics_pins`, `online_lyrics_rejects`
//    and `lyrics_source_prefs`. It starts with `plugin-`, is assigned once and
//    never reused for another package.
// 2. `removed_at` set means "removed": the plugin is gone (package files,
//    config, storage, preference, not-found rows) but saved lyrics, pins or
//    rejects still name its id, so the record stays to give them a name.
//    Saved translations count too: a `lyric_translations.provider` equal to
//    the id is a reference, so an uninstalled translate plugin with saved
//    translations stays as a removed record.
//    The record is hard-deleted when nothing points to it: at uninstall, by
//    `clearLyricsPluginSavedLyrics` once the last row is gone, by "clear
//    online lyrics" and by "clear saved translations" (all four use the one
//    `removedAndUnreferencedPluginSql` predicate). Removing the last pin or
//    reject elsewhere does not delete it; it stays until one of those.
//    Reinstalling the same repo plugin revives the record and keeps the id.
//    Preferences are never written for a missing or removed plugin.
// 3. `(repo_url, repo_slug)` is unique among records with a `repo_url`; file
//    installs have none. Removed records count, so a revive finds its record.
// 4. `package_dir` is the relative directory of the current package. A new
//    version switches `package_dir`, `version`, `hosts`, `config_schema`,
//    `translate_spec` and `updated_at` in one statement; config values,
//    storage and preferences are kept. Directories no record points to are swept at startup.
// 5. `updated_at` changes on every install, revive and package switch. A
//    script run remembers it and writes its storage back only while it still
//    matches (`setLyricsPluginStorage`), so a run that outlived an uninstall
//    or an update writes nothing.
// 6. `hosts`, `config_schema` and `translate_spec` are JSON text the plugin
//    layer owns; this layer stores them as given. Secret config values are
//    never stored here.
// 7. `lyrics_plugin_data` holds one row per live plugin: non-secret config
//    values and the script's localStorage, both JSON objects (default `{}`),
//    each at most 64 KiB. No source list or lyrics stream watches the table,
//    so a config or storage write never rebuilds them. Only the config forms
//    watch `config_values`, through a distinct stream of that text. The row
//    goes with the plugin on uninstall.
// 8. `lyrics_source_prefs` has one row per lyrics source the user changed or
//    ordered. A source with no row is enabled and goes after the rows. Rows
//    for ids with no plugin record are ignored. Translate plugins never get a
//    row.
// 9. `lyrics_plugin_repos.catalog` is the last good catalog (at most 1 MiB)
//    and survives a failed fetch; `last_error` is a kind string only.
//    `last_fetched_at` is the last successful fetch.
// 10. No foreign keys and no CHECK constraints: readers skip values they do
//    not know, so a newer build's rows do not break an older one.
// 11. `kind` is `lyrics`, `translate`, `ai-translate` or `source`, set at
//    first install. An update may change it only within the translation
//    family (`translate` and `ai-translate`); any other change is refused.
//    A revive of a removed record may write any kind.
//    A revive that changes the kind keeps the old saved lyrics, pins and
//    rejects under the id: they stay named and go only with the global
//    clear. Lists skip kinds they do not know.

/// One installed (or removed, see invariant 2) lyrics plugin.
@DataClassName('LyricsPluginRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX lyrics_plugins_repo_unique '
  'ON lyrics_plugins (repo_url, repo_slug) WHERE repo_url IS NOT NULL',
)
class LyricsPlugins extends Table {
  TextColumn get installId => text()();

  TextColumn get name => text()();

  TextColumn get author => text().nullable()();

  TextColumn get description => text().nullable()();

  IntColumn get version => integer()();

  IntColumn get apiVersion => integer()();

  /// JSON array of the hosts the plugin may reach.
  TextColumn get hosts => text()();

  /// JSON text of the config form the package declares.
  TextColumn get configSchema => text()();

  /// JSON of the `translate` block (`PluginTranslateSpec.toJson`) for
  /// translation plugins; null for lyrics plugins, and for a translation
  /// plugin installed before the column existed until the startup backfill.
  TextColumn get translateSpec => text().nullable()();

  /// Relative directory of the current package.
  TextColumn get packageDir => text()();

  /// `file` or `repo`.
  TextColumn get sourceKind => text()();

  /// The file name, or the repository name, at install time.
  TextColumn get sourceName => text()();

  TextColumn get repoUrl => text().nullable()();

  TextColumn get repoSlug => text().nullable()();

  IntColumn get installedAt => integer()();

  IntColumn get updatedAt => integer()();

  /// `lyrics`, `translate` or `ai-translate`; see invariant 11. Rows from
  /// before the column existed read as `lyrics` through the SQL default.
  TextColumn get kind => text().withDefault(const Constant('lyrics'))();

  /// Set while the record is only a name for saved lyrics.
  IntColumn get removedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {installId};
}

/// Whether a source is on, and where it sits in the order.
@DataClassName('LyricsSourcePrefRow')
class LyricsSourcePrefs extends Table {
  TextColumn get providerId => text()();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {providerId};
}

/// A plugin repository the user added.
@DataClassName('LyricsPluginRepoRow')
class LyricsPluginRepos extends Table {
  TextColumn get url => text()();

  TextColumn get name => text()();

  TextColumn get author => text().nullable()();

  IntColumn get addedAt => integer()();

  IntColumn get lastFetchedAt => integer().nullable()();

  /// Kind of the last failed fetch; null after a success.
  TextColumn get lastError => text().nullable()();

  /// The last good catalog, as JSON text.
  TextColumn get catalog => text().nullable()();

  @override
  Set<Column> get primaryKey => {url};
}

/// Config values and localStorage of one plugin; see invariant 7.
@DataClassName('LyricsPluginDataRow')
class LyricsPluginData extends Table {
  TextColumn get installId => text()();

  TextColumn get configValues => text().withDefault(const Constant('{}'))();

  TextColumn get storage => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {installId};
}
