/// How a config field is edited.
enum PluginConfigMode { input, select, toggle }

/// Text entry kind of an `input` field.
enum PluginInputFormat { text, number, secret }

/// One choice of a `select` field.
class PluginConfigOption {
  const PluginConfigOption({required this.value, required this.title});

  final String value;
  final String title;
}

/// One setting a plugin asks the user for.
class PluginConfigField {
  const PluginConfigField({
    required this.key,
    required this.title,
    required this.mode,
    this.inputFormat,
    this.options = const [],
    this.defaultValue,
  });

  /// Name the script reads with `localConfig.getItem(key)`.
  final String key;
  final String title;
  final PluginConfigMode mode;

  /// Set for `input` fields only.
  final PluginInputFormat? inputFormat;

  /// Set for `select` fields only.
  final List<PluginConfigOption> options;

  /// Initial value: a `String` for `input` (numbers as text) and `select`, a
  /// `bool` for `toggle`; null when the manifest gives none.
  final Object? defaultValue;
}

/// A checked `plugin.json`. The type is always `lyrics`, so it is not kept.
class PluginManifest {
  const PluginManifest({
    required this.apiVersion,
    required this.name,
    required this.version,
    required this.hosts,
    required this.searchScript,
    required this.lyricsScript,
    this.author = '',
    this.description = '',
    this.config = const [],
  });

  final int apiVersion;
  final String name;
  final int version;

  /// Lower-case, deduplicated, each passed `lyricsHostProblem`.
  final List<String> hosts;

  /// File names inside `src/`.
  final String searchScript;
  final String lyricsScript;
  final String author;
  final String description;
  final List<PluginConfigField> config;
}
