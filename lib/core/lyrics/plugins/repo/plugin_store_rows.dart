import '../../../database/lyrics_plugin_spec.dart';
import '../lyrics_plugin_record.dart';
import 'plugin_catalog.dart';
import 'plugin_repo.dart';

/// What the store list shows: all, one repository, or plugins from a file.
class StoreSourceFilter {
  const StoreSourceFilter.all() : repoUrl = null, _fromFile = false;
  const StoreSourceFilter.fromFile() : repoUrl = null, _fromFile = true;
  const StoreSourceFilter.repo(String this.repoUrl) : _fromFile = false;

  final String? repoUrl;
  final bool _fromFile;

  bool get isAll => repoUrl == null && !_fromFile;
  bool get isFromFile => _fromFile;

  @override
  bool operator ==(Object other) =>
      other is StoreSourceFilter &&
      other.repoUrl == repoUrl &&
      other._fromFile == _fromFile;

  @override
  int get hashCode => Object.hash(repoUrl, _fromFile);
}

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
