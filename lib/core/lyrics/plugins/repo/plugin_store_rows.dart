import '../../../database/lyrics_plugin_spec.dart';
import '../lyrics_plugin_record.dart';
import 'plugin_catalog.dart';
import 'plugin_repo.dart';

/// One row of the store list or the data of a catalog item page.
class StoreRow {
  const StoreRow({
    required this.name,
    required this.author,
    required this.hosts,
    this.record,
    this.entry,
    this.repoUrl,
    this.repoName,
    this.languages = const [],
  });

  final String name;
  final String author;
  final List<String> hosts;

  /// The live installed plugin; null for a plugin not installed. Its icon is
  /// the installed package's.
  final LyricsPluginRecord? record;

  /// The catalog entry, when the plugin's repository is still added and
  /// lists it. Its [PluginCatalogEntry.icon] is the icon address of a plugin
  /// not installed.
  final PluginCatalogEntry? entry;

  /// The repository the plugin belongs to; null for a plugin from a file.
  /// For a plugin whose repository was removed this is the stored address.
  final String? repoUrl;

  /// The repository name; for an installed plugin whose repository was
  /// removed, the name stored at install.
  final String? repoName;

  /// Normalized language keys (see `parsePluginLanguages`); empty = global.
  /// The catalog entry's when it declares any, else the installed package's.
  final List<String> languages;

  /// The plugin's kind; the installed record's wins over the catalog's.
  PluginKind? get kind => record?.kind ?? entry?.kind;

  bool get isInstalled => record != null;
  bool get isFromFile => record?.sourceKind == LyricsPluginSourceKind.file;
  Uri? get catalogIcon => entry?.icon;
}

/// A repository that failed its last fetch.
class FailingRepo {
  const FailingRepo(this.url, this.name, this.error);

  final String url;
  final String name;
  final RepoLoadError error;
}
