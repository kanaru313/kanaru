import 'dart:async';

import 'package:logging/logging.dart';

import '../../../database/library_database.dart';
import '../../../database/lyrics_plugin_queries.dart';
import 'plugin_catalog.dart';
import 'plugin_repo.dart';
import 'plugin_repo_reader.dart';
import 'repo_fetch_exception.dart';
import 'repo_http.dart';
import 'repo_operation_results.dart';

final _log = Logger('lyrics_plugin_repos');

/// At most this many repositories are fetched at once by a refresh.
const repoRefreshParallelism = 4;

/// Fetches catalogs and stores them or the error kind. A repository being
/// fetched is fetched once: [refresh] and [refreshAll] share the running fetch
/// of one URL. Repositories for which [isAdding] is true are left alone, so a
/// refresh cannot write an error over the catalog an add is about to store.
class RepoRefreshRunner {
  RepoRefreshRunner({
    required this._db,
    required this._http,
    required this._reader,
    required this._now,
    required this._isAdding,
  });

  final LibraryDatabase _db;
  final RepoHttp _http;
  final PluginRepoReader _reader;
  final int Function() _now;
  final bool Function(String url) _isAdding;

  Future<List<RepoRefreshResult>>? _refreshingAll;
  final _refreshingOne = <String, Future<RepoRefreshResult?>>{};

  /// Fetches and parses the catalog at [url]: the catalog and the form to store.
  Future<({PluginCatalog catalog, String stored})> fetch(String url) async {
    final response = await _http.fetchCatalog(Uri.parse(url));
    final catalog = parsePluginCatalog(response.bytes, (
      url: response.finalUrl,
      kind: response.kind,
    ));
    return (
      catalog: catalog,
      stored: encodeStoredCatalog(catalog, response.kind),
    );
  }

  /// Refreshes every repository, [repoRefreshParallelism] at once. A call made
  /// while another runs shares its result. Never throws: when the repositories
  /// cannot be listed the result is empty.
  Future<List<RepoRefreshResult>> refreshAll() =>
      _refreshingAll ??= _refreshAll().whenComplete(() {
        _refreshingAll = null;
      });

  /// Refreshes the one repository at [url]. Null when it is not added any
  /// more, is being added, or was removed meanwhile. Shares the fetch already
  /// running for [url] (from [refreshAll] too). Never throws.
  Future<RepoRefreshResult?> refresh(String url) async {
    if (_isAdding(url)) return null;
    try {
      final listed = await _db.watchLyricsPluginRepos().first;
      if (!listed.any((r) => r.url == url)) return null;
    } on Object catch (error) {
      _log.warning('Listing repositories failed: ${error.runtimeType}');
      return null;
    }
    return _refreshOne(url);
  }

  Future<List<RepoRefreshResult>> _refreshAll() async {
    final List<String> urls;
    try {
      urls = [
        for (final repo in await _db.watchLyricsPluginRepos().first)
          if (!_isAdding(repo.url)) repo.url,
      ];
    } on Object catch (error) {
      _log.warning('Listing repositories failed: ${error.runtimeType}');
      return const [];
    }
    final results = List<RepoRefreshResult?>.filled(urls.length, null);
    var next = 0;
    Future<void> worker() async {
      while (next < urls.length) {
        final i = next++;
        results[i] = await _refreshOne(urls[i]);
      }
    }

    await Future.wait([
      for (var i = 0; i < repoRefreshParallelism && i < urls.length; i++)
        worker(),
    ]);
    return List.unmodifiable(results.nonNulls);
  }

  Future<RepoRefreshResult?> _refreshOne(String url) =>
      _refreshingOne[url] ??= _fetchAndStore(url).whenComplete(() {
        _refreshingOne.remove(url);
      });

  Future<RepoRefreshResult?> _fetchAndStore(String url) async {
    RepoLoadError? error;
    try {
      final fetched = await fetch(url);
      final saved = await _db.saveLyricsPluginRepoFetch(
        url,
        catalog: fetched.stored,
        now: _now(),
      );
      if (saved == LyricsPluginWrite.skipped) return null;
      if (saved == LyricsPluginWrite.tooLarge) {
        error = const RepoLoadError(RepoFetchErrorKind.tooLarge);
      }
    } on RepoFetchException catch (failure) {
      error = RepoLoadError.of(failure);
    } on Object catch (failure) {
      _log.warning('Refreshing a repository failed: ${failure.runtimeType}');
      error = const RepoLoadError(RepoFetchErrorKind.network);
    }
    // Only the kind is stored; the reason of a refused address is kept here,
    // before the write so the emission that follows carries it.
    _reader.setReason(url, error?.reason);
    if (error != null && !_isAdding(url)) {
      try {
        final saved = await _db.saveLyricsPluginRepoFetch(
          url,
          error: error.encode(),
          now: _now(),
        );
        if (saved == LyricsPluginWrite.skipped) return null;
      } on Object catch (failure) {
        _log.warning('Saving a fetch error failed: ${failure.runtimeType}');
      }
    }
    return RepoRefreshResult(url, error);
  }
}
