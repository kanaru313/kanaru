import '../../../database/lyrics_plugin_spec.dart';
import 'plugin_translate_spec.dart';

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
    this.subtitle,
    this.inputFormat,
    this.options = const [],
    this.defaultValue,
  });

  /// Name the script reads with `localConfig.getItem(key)`.
  final String key;
  final String title;
  final PluginConfigMode mode;

  /// Optional help text under the title; may hold newlines.
  final String? subtitle;

  /// Set for `input` fields only.
  final PluginInputFormat? inputFormat;

  /// Set for `select` fields only.
  final List<PluginConfigOption> options;

  /// Initial value: a `String` for `input` (numbers as text) and `select`, a
  /// `bool` for `toggle`; null when the manifest gives none.
  final Object? defaultValue;
}

/// A checked `plugin.json`.
class PluginManifest {
  const PluginManifest({
    required this.kind,
    required this.apiVersion,
    required this.name,
    required this.version,
    required this.hosts,
    this.searchScript,
    this.lyricsScript,
    this.translateScript,
    this.translate,
    this.author = '',
    this.description = '',
    this.languages = const [],
    this.config = const [],
  });

  final PluginKind kind;
  final int apiVersion;
  final String name;
  final int version;

  /// Lower-case, deduplicated, each passed `lyricsHostProblem`.
  final List<String> hosts;

  /// File names inside `src/`: `search` and `lyrics` for a lyrics plugin,
  /// `translate` for a translate plugin; the others are null.
  final String? searchScript;
  final String? lyricsScript;
  final String? translateScript;

  /// The `translate` block; set exactly for a translate plugin.
  final PluginTranslateSpec? translate;
  final String author;
  final String description;

  /// Normalized language keys the plugin serves (`vie`, `zho`); empty means
  /// global (any language). Only the store's Language filter reads it.
  final List<String> languages;
  final List<PluginConfigField> config;

  /// The entry script names of this kind, all non-null.
  List<String> get entryScripts => [
    ?searchScript,
    ?lyricsScript,
    ?translateScript,
  ];
}
