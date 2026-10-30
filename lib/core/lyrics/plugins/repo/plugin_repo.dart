import 'dart:convert';
import 'dart:typed_data';

import '../../../database/library_database.dart';
import 'plugin_catalog.dart';
import 'repo_address_rules.dart';
import 'repo_fetch_exception.dart';

/// Why the last fetch of a repository failed: the app maps [kind] (and
/// [reason] for a refused address) to text. The last good catalog is kept.
///
/// Only [kind] is persisted (`lyrics_plugin_repos.last_error` is a kind
/// string); [reason] is kept in memory by [PluginRepoReader] and so is only
/// known for a failure seen in this session.
class RepoLoadError {
  const RepoLoadError(this.kind, {this.reason});

  /// Reads the text [encode] wrote; null for anything else. [reason] is
  /// attached only to a refused address.
  static RepoLoadError? decode(String? text, {RepoAddressProblem? reason}) {
    final kind = RepoFetchErrorKind.values.asNameMap()[text];
    if (kind == null) return null;
    return RepoLoadError(
      kind,
      reason: kind == RepoFetchErrorKind.blockedAddress ? reason : null,
    );
  }

  factory RepoLoadError.of(RepoFetchException error) =>
      RepoLoadError(error.kind, reason: error.reason);

  final RepoFetchErrorKind kind;
  final RepoAddressProblem? reason;

  /// The text kept in `lyrics_plugin_repos.last_error`: the kind only.
  String encode() => kind.name;

  @override
  bool operator ==(Object other) =>
      other is RepoLoadError && other.kind == kind && other.reason == reason;

  @override
  int get hashCode => Object.hash(kind, reason);
}

/// A decoded stored catalog and the address class kept with it.
typedef StoredCatalog = ({PluginCatalog catalog, RepoAddressKind kind});

/// One added repository with the catalog of its last good fetch.
class PluginRepo {
  const PluginRepo({
    required this.url,
    required this.name,
    required this.author,
    required this.addedAt,
    this.lastFetchedAt,
    this.error,
    this.catalog,
    this.kind,
  });

  /// Reads a table row. A stored catalog that cannot be read counts as none.
  /// [decode] reads the stored text (default: parse it); [errorReason] is the
  /// in-memory reason of a refused address. See [PluginRepoReader], which
  /// avoids parsing an unchanged catalog again.
  factory PluginRepo.fromRow(
    LyricsPluginRepoRow row, {
    StoredCatalog? Function(String repoUrl, String text) decode =
        decodeStoredCatalog,
    RepoAddressProblem? errorReason,
  }) {
    final stored = row.catalog == null ? null : decode(row.url, row.catalog!);
    return PluginRepo(
      url: row.url,
      name: row.name,
      author: row.author ?? '',
      addedAt: row.addedAt,
      lastFetchedAt: row.lastFetchedAt,
      error: RepoLoadError.decode(row.lastError, reason: errorReason),
      catalog: stored?.catalog,
      kind: stored?.kind,
    );
  }

  /// Normalized address; the identity of the repository.
  final String url;
  final String name;
  final String author;
  final int addedAt;
  final int? lastFetchedAt;

  /// Set when the last fetch failed.
  final RepoLoadError? error;

  /// The last good catalog; null before the first success.
  final PluginCatalog? catalog;

  /// The address class of the repository at that fetch; set with [catalog].
  final RepoAddressKind? kind;

  PluginCatalogEntry? entry(String slug) {
    for (final entry in catalog?.entries ?? const <PluginCatalogEntry>[]) {
      if (entry.slug == slug) return entry;
    }
    return null;
  }
}

/// A catalog as kept in the database: the checked entries with absolute
/// addresses, and the class of the repository when it was fetched. Reading it
/// back needs no address resolution, and it is never the server's raw text.
String encodeStoredCatalog(PluginCatalog catalog, RepoAddressKind kind) =>
    jsonEncode({
      'kind': kind.name,
      'metadata': {
        'name': catalog.name,
        if (catalog.author.isNotEmpty) 'author': catalog.author,
      },
      'data': [
        for (final e in catalog.entries)
          {
            'slug': e.slug,
            'name': e.name,
            'version': e.version,
            'apiVersion': e.apiVersion,
            'type': 'lyrics',
            'hosts': e.hosts,
            'path': e.path.toString(),
            if (e.icon != null) 'icon': e.icon.toString(),
            if (e.description.isNotEmpty) 'description': e.description,
            if (e.author.isNotEmpty) 'author': e.author,
          },
      ],
    });

/// Reads [text] written by [encodeStoredCatalog] for the repository at
/// [repoUrl]; null when it is not that.
StoredCatalog? decodeStoredCatalog(String repoUrl, String text) {
  try {
    final json = jsonDecode(text);
    final kind = json is Map<String, dynamic>
        ? RepoAddressKind.values.asNameMap()[json['kind']]
        : null;
    if (kind == null) return null;
    final catalog = parsePluginCatalog(Uint8List.fromList(utf8.encode(text)), (
      url: Uri.parse(repoUrl),
      kind: kind,
    ));
    return (catalog: catalog, kind: kind);
  } on Object {
    // A damaged or foreign value: the repository shows as never fetched.
    return null;
  }
}
