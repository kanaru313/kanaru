import 'repo_address_rules.dart';

export 'plugin_catalog_parser.dart';

/// One plugin a catalog offers. The fields come from the catalog and are only
/// shown before install; what gets installed is read from the zip's own
/// manifest, which must agree with [version] and [hosts].
class PluginCatalogEntry {
  const PluginCatalogEntry({
    required this.slug,
    required this.name,
    required this.version,
    required this.apiVersion,
    required this.hosts,
    required this.path,
    this.icon,
    this.description = '',
    this.author = '',
  });

  /// `^[a-z0-9_-]{1,64}$`, unique within the catalog.
  final String slug;
  final String name;
  final int version;

  /// May be newer than this app understands; the store hides such entries.
  final int apiVersion;

  /// Lower-case public host names, each checked like a manifest host.
  final List<String> hosts;

  /// Absolute address of the plugin zip, already resolved against the
  /// catalog and statically checked against the address rules.
  final Uri path;

  /// Absolute address of the icon, or null when absent or refused.
  final Uri? icon;
  final String description;
  final String author;
}

/// A parsed catalog: its display [name] and [author], the usable [entries]
/// and how many entries were [dropped] (invalid, refused address or a
/// repeated slug).
class PluginCatalog {
  const PluginCatalog({
    required this.name,
    required this.author,
    required this.entries,
    required this.dropped,
  });

  final String name;
  final String author;
  final List<PluginCatalogEntry> entries;
  final int dropped;
}

/// The class of the repository a catalog came from, kept next to the parse
/// input so callers pass the two together.
typedef PluginCatalogOrigin = ({Uri url, RepoAddressKind kind});
