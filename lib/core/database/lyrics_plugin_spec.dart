/// Provider id of the built-in LRCLIB source.
const lrclibSourceId = 'lrclib';

/// Every plugin source id starts with this; `lyrics_plugins.install_id` is
/// the whole id.
const lyricsPluginIdPrefix = 'plugin-';

/// Largest JSON text kept in a plugin's config values or storage (64 KiB).
const lyricsPluginDataMaxBytes = 64 * 1024;

/// Largest catalog kept for one plugin repository (1 MiB).
const lyricsPluginCatalogMaxBytes = 1024 * 1024;

/// Whether [providerId] names a plugin source.
bool isLyricsPluginId(String providerId) =>
    providerId.startsWith(lyricsPluginIdPrefix);

/// Where a plugin was installed from (`lyrics_plugins.source_kind`).
enum LyricsPluginSourceKind {
  file('file'),
  repo('repo');

  const LyricsPluginSourceKind(this.value);

  /// The text stored in the column.
  final String value;
}

/// What a package says about itself; the columns an install, a revive and a
/// package switch write together.
class LyricsPluginSpec {
  const LyricsPluginSpec({
    required this.name,
    this.author,
    this.description,
    required this.version,
    required this.apiVersion,
    required this.hosts,
    required this.configSchema,
    required this.packageDir,
    this.sourceKind = LyricsPluginSourceKind.file,
    required this.sourceName,
    this.repoUrl,
    this.repoSlug,
  });

  final String name;
  final String? author;
  final String? description;
  final int version;
  final int apiVersion;

  /// Stored as a JSON array.
  final List<String> hosts;

  /// JSON text, stored as given.
  final String configSchema;
  final String packageDir;
  final LyricsPluginSourceKind sourceKind;
  final String sourceName;
  final String? repoUrl;
  final String? repoSlug;
}

/// How a guarded write ended.
enum LyricsPluginWrite {
  /// The row was written.
  written,

  /// Nothing was written: the plugin or repository is gone, removed, or (for
  /// storage) changed since the run began.
  skipped,

  /// Nothing was written: the text is over its size cap.
  tooLarge,
}

/// How an uninstall ended.
enum LyricsPluginUninstall {
  /// No such record.
  missing,

  /// The record is already marked removed; nothing was changed.
  alreadyRemoved,

  /// Saved lyrics, a pin or a reject still name the plugin: the record stays,
  /// marked removed.
  markedRemoved,

  /// Nothing points to the plugin: the record is gone.
  deleted,
}
