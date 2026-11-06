import '../../../database/lyrics_plugin_spec.dart';
import 'plugin_config_field.dart';
import 'plugin_translate_spec.dart';

export 'plugin_config_field.dart';

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
    this.streamScript,
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

  /// Lower-case, deduplicated, each passed `pluginHostListProblem`: plain host
  /// names, plus `*.` wildcards for a source plugin only.
  final List<String> hosts;

  /// File names inside `src/`: `search` and `lyrics` for a lyrics plugin,
  /// `translate` for a translate plugin, `search` and `stream` for a source
  /// plugin; the others are null.
  final String? searchScript;
  final String? lyricsScript;
  final String? translateScript;
  final String? streamScript;

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
    ?streamScript,
  ];
}
