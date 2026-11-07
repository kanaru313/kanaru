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

/// SQL condition on `lyrics_plugins` (unaliased) for a removed record that
/// nothing names any more: no found lyrics, pin, reject, saved translation
/// or per-song service choice points to its id. Every delete of removed
/// records uses this one text, so they cannot disagree (invariant 2).
const removedAndUnreferencedPluginSql =
    'removed_at IS NOT NULL '
    'AND NOT EXISTS (SELECT 1 FROM online_lyrics '
    'WHERE provider_id = lyrics_plugins.install_id) '
    'AND NOT EXISTS (SELECT 1 FROM lyrics_pins '
    'WHERE provider_id = lyrics_plugins.install_id) '
    'AND NOT EXISTS (SELECT 1 FROM online_lyrics_rejects '
    'WHERE provider_id = lyrics_plugins.install_id) '
    'AND NOT EXISTS (SELECT 1 FROM lyric_translations '
    'WHERE provider = lyrics_plugins.install_id) '
    'AND NOT EXISTS (SELECT 1 FROM lyric_translation_prefs '
    'WHERE service = lyrics_plugins.install_id)';

/// Where a plugin was installed from (`lyrics_plugins.source_kind`).
enum LyricsPluginSourceKind {
  file('file'),
  repo('repo');

  const LyricsPluginSourceKind(this.value);

  /// The text stored in the column.
  final String value;
}

/// What a plugin does (`lyrics_plugins.kind`).
enum PluginKind {
  lyrics('lyrics'),
  translate('translate'),
  aiTranslate('ai-translate');

  const PluginKind(this.value);

  /// The text stored in the column.
  final String value;

  /// Whether this kind belongs to the translation family.
  bool get isTranslation => this == translate || this == aiTranslate;

  /// Whether a record stored with [stored] kind satisfies a request expecting
  /// this kind.
  ///
  /// Matches exact kinds, or allows either translation kind to fulfill
  /// translation requests.
  bool accepts(String stored) {
    final k = fromValue(stored);
    return k == this || (isTranslation && (k?.isTranslation ?? false));
  }

  /// The kind stored as [text]; null for text this build does not know.
  static PluginKind? fromValue(String text) {
    for (final kind in values) {
      if (kind.value == text) return kind;
    }
    return null;
  }
}

/// What a package says about itself; the columns an install, a revive and a
/// package switch write together.
class LyricsPluginSpec {
  const LyricsPluginSpec({
    required this.kind,
    required this.name,
    this.author,
    this.description,
    required this.version,
    required this.apiVersion,
    required this.hosts,
    required this.configSchema,
    this.translateSpec,
    required this.packageDir,
    this.sourceKind = LyricsPluginSourceKind.file,
    required this.sourceName,
    this.repoUrl,
    this.repoSlug,
  });

  /// Written by an insert, a revive and a package switch (the caller only
  /// switches within the translation family).
  final PluginKind kind;
  final String name;
  final String? author;
  final String? description;
  final int version;
  final int apiVersion;

  /// Stored as a JSON array.
  final List<String> hosts;

  /// JSON text, stored as given.
  final String configSchema;

  /// JSON of the `translate` block; null for lyrics plugins.
  final String? translateSpec;
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

  /// Saved lyrics, a pin, a reject or a saved translation still name the
  /// plugin: the record stays, marked removed.
  markedRemoved,

  /// Nothing points to the plugin: the record is gone.
  deleted,
}
