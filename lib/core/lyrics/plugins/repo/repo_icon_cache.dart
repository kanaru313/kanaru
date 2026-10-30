import 'dart:typed_data';

import '../package/plugin_icon_check.dart';
import 'plugin_catalog.dart';
import 'plugin_repo.dart';
import 'repo_address_rules.dart';
import 'repo_fetch_exception.dart';
import 'repo_http.dart';

/// Most bytes of icons kept; the least recently used go first.
const repoIconCacheMaxBytes = 8 * 1024 * 1024;

/// What a missing icon counts for in the budget (so many of them cannot grow
/// the map without bound).
const _missingCost = 64;

/// How long a network failure (an icon, or the lookup of its repository) is
/// remembered before the next ask tries again.
const repoIconRetryAfter = Duration(seconds: 60);

/// Icons of catalog entries, fetched on first use and kept in memory (no
/// disk cache), at most [repoIconCacheMaxBytes] with the least recently used
/// dropped first. An icon that failed a definitive check (not a PNG, too
/// large, refused address, not found) is remembered as missing, so a list
/// does not refetch it on every rebuild; a network failure is remembered for
/// [repoIconRetryAfter] only, or until [clearFailures]; so is a failed or
/// refused recheck of the repository's own address. Concurrent asks for
/// one icon share one fetch.
///
/// An icon obeys the stricter of its repository's stored class and a fresh
/// look at the repository address ([RepoHttp.effectiveKind]), done once per
/// repository for a burst of icons.
class RepoIconCache {
  RepoIconCache(
    this._http, {
    this._maxBytes = repoIconCacheMaxBytes,
    this._retryAfter = repoIconRetryAfter,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RepoHttp _http;
  final int _maxBytes;
  final Duration _retryAfter;
  final DateTime Function() _clock;

  /// Insertion order is use order: a hit moves the entry to the end.
  final _icons = <String, Uint8List?>{};
  var _bytes = 0;
  final _loading = <String, Future<Uint8List?>>{};
  final _networkFailedAt = <String, DateTime>{};
  final _kinds = <String, ({Future<RepoAddressKind> kind, DateTime at})>{};

  /// The icon of [entry] from [repo]'s catalog, or null when it has none, the
  /// repository kind is unknown, or the fetch or the PNG check failed.
  Future<Uint8List?> iconOf(PluginRepo repo, PluginCatalogEntry entry) {
    final url = entry.icon;
    final stored = repo.kind;
    if (url == null || stored == null) return Future.value();
    final key = '${stored.name}\n${repo.url}\n$url';
    if (_icons.containsKey(key)) {
      final icon = _icons.remove(key);
      _icons[key] = icon;
      return Future.value(icon);
    }
    final failedAt = _networkFailedAt[key];
    if (failedAt != null) {
      if (_clock().difference(failedAt) < _retryAfter) return Future.value();
      _networkFailedAt.remove(key);
    }
    return _loading[key] ??= _load(key, repo.url, stored, url).whenComplete(() {
      // A block body: returning the removed future would make it wait on itself.
      _loading.remove(key);
    });
  }

  /// Forgets remembered network failures, so the next ask tries again. Call
  /// after "refresh all".
  void clearFailures() {
    _networkFailedAt.clear();
    _kinds.clear();
  }

  Future<Uint8List?> _load(
    String key,
    String repoUrl,
    RepoAddressKind stored,
    Uri url,
  ) async {
    Uint8List? icon;
    final RepoAddressKind kind;
    try {
      kind = await _kindOf(repoUrl, stored);
    } on RepoFetchException {
      // The recheck of the repository's own address failed or refused it
      // (not the icon's address): that can change, so retry after the window
      // like a network failure, and let [clearFailures] forget it.
      _networkFailedAt[key] = _clock();
      return null;
    }
    try {
      final response = await _http.fetchIcon(url, catalogKind: kind);
      icon = pluginIconProblem(response.bytes) == null ? response.bytes : null;
    } on RepoFetchException catch (error) {
      if (error.kind == RepoFetchErrorKind.network) {
        _networkFailedAt[key] = _clock();
        return null;
      }
    }
    _remember(key, icon);
    return icon;
  }

  Future<RepoAddressKind> _kindOf(String repoUrl, RepoAddressKind stored) {
    final memoKey = '${stored.name}\n$repoUrl';
    final known = _kinds[memoKey];
    if (known != null && _clock().difference(known.at) < _retryAfter) {
      return known.kind;
    }
    final kind = _http.effectiveKind(Uri.parse(repoUrl), stored);
    _kinds[memoKey] = (kind: kind, at: _clock());
    // A failed lookup must not be reused for the next icon.
    kind.then<void>(
      (_) {},
      onError: (Object _) {
        _kinds.remove(memoKey);
      },
    );
    return kind;
  }

  void _remember(String key, Uint8List? icon) {
    _icons[key] = icon;
    _bytes += icon?.length ?? _missingCost;
    while (_bytes > _maxBytes && _icons.length > 1) {
      final oldest = _icons.keys.first;
      _bytes -= _icons.remove(oldest)?.length ?? _missingCost;
    }
  }
}
