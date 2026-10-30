import 'dart:async';

import 'package:logging/logging.dart';

import '../../../database/library_database.dart';
import '../../../database/lyrics_plugin_queries.dart';
import '../lyrics_plugins_controller.dart';
import '../package/plugin_package_reader.dart';
import 'plugin_catalog.dart';
import 'plugin_repo.dart';
import 'plugin_repo_reader.dart';
import 'repo_address_rules.dart';
import 'repo_fetch_exception.dart';
import 'repo_http.dart';
import 'repo_operation_results.dart';
import 'repo_plugin_installer.dart';
import 'repo_url.dart';

export 'plugin_repo.dart' show PluginRepo, RepoLoadError;
export 'repo_operation_results.dart';

final _log = Logger('lyrics_plugin_repos');

/// At most this many repositories are fetched at once by a refresh.
const repoRefreshParallelism = 4;

/// Repositories and what they offer: add, remove, refresh, and install or
/// update a plugin from a catalog. Fetches happen only when called (the
/// store opens, "refresh all", add, install, update); there is no timer.
/// Nothing here sends song data and it is not gated by lyrics consent. No UI
/// text: failures are enums.
class LyricsPluginReposController {
  LyricsPluginReposController({
    required this._db,
    required LyricsPluginsController plugins,
    required PluginPackageReader reader,
    RepoHttp? http,
    DateTime Function()? clock,
  }) : _http = http ?? RepoHttp(),
       _clock = clock ?? DateTime.now {
    _installer = RepoPluginInstaller(
      db: _db,
      plugins: plugins,
      reader: reader,
      http: _http,
      repoReader: _reader,
    );
  }

  final LibraryDatabase _db;
  final RepoHttp _http;
  final DateTime Function() _clock;
  final _reader = PluginRepoReader();
  late final RepoPluginInstaller _installer;
  Future<List<RepoRefreshResult>>? _refreshing;

  /// Repositories being added: a refresh leaves them alone, so it cannot
  /// write an error over the catalog the add is about to store.
  final _adding = <String>{};

  /// The repositories, oldest first, with their last good catalog.
  Stream<List<PluginRepo>> watchRepos() =>
      _db.watchLyricsPluginRepos().map(_reader.readAll);

  /// Adds the repository at [input] after fetching its catalog once. A
  /// failure after the row was inserted removes it again.
  Future<AddRepoResult> add(String input) async {
    final url = normalizeRepoUrl(input);
    if (url == null) return const AddRepoFailed(AddRepoFailure.invalidUrl);
    var inserted = false;
    var stored = false;
    _adding.add(url);
    try {
      if ((await _db.watchLyricsPluginRepos().first).any((r) => r.url == url)) {
        return const AddRepoFailed(AddRepoFailure.duplicate);
      }
      final fetched = await _fetch(url);
      final catalog = fetched.catalog;
      inserted = await _db.addLyricsPluginRepo(
        url,
        name: catalog.name,
        author: catalog.author.isEmpty ? null : catalog.author,
        now: _now(),
      );
      if (!inserted) return const AddRepoFailed(AddRepoFailure.duplicate);
      final saved = await _db.saveLyricsPluginRepoFetch(
        url,
        catalog: fetched.stored,
        now: _now(),
      );
      if (saved != LyricsPluginWrite.written) {
        return const AddRepoFailed(AddRepoFailure.badFormat);
      }
      stored = true;
      return AddRepoAdded(
        url: url,
        name: catalog.name,
        pluginCount: catalog.entries.length,
      );
    } on RepoFetchException catch (error) {
      return AddRepoFailed(_failureOf(error), addressProblem: error.reason);
    } on Object catch (error) {
      _log.warning('Adding a repository failed: ${error.runtimeType}');
      return const AddRepoFailed(AddRepoFailure.storage);
    } finally {
      _adding.remove(url);
      if (inserted && !stored) {
        try {
          await _db.removeLyricsPluginRepo(url);
        } on Object catch (error) {
          _log.warning(
            'Removing a half-added repository failed: ${error.runtimeType}',
          );
        }
      }
    }
  }

  /// Removes the repository. Installed plugins stay; they only lose updates.
  /// False when [url] is not added.
  Future<bool> remove(String url) => _db.removeLyricsPluginRepo(url);

  /// Fetches every repository, at most [repoRefreshParallelism] at once, and
  /// stores each catalog or the error kind (an old catalog stays on error).
  /// A repository removed meanwhile, or being added, is left out of the
  /// result. A call made while another runs shares its result. Never throws:
  /// when the repositories cannot be listed the result is empty.
  Future<List<RepoRefreshResult>> refreshAll() =>
      _refreshing ??= _refreshAll().whenComplete(() => _refreshing = null);

  Future<List<RepoRefreshResult>> _refreshAll() async {
    final List<String> urls;
    try {
      urls = [
        for (final repo in await _db.watchLyricsPluginRepos().first)
          if (!_adding.contains(repo.url)) repo.url,
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

  /// Null when the repository was removed (or is being added) meanwhile.
  Future<RepoRefreshResult?> _refreshOne(String url) async {
    RepoLoadError? error;
    try {
      final fetched = await _fetch(url);
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
    if (error != null && !_adding.contains(url)) {
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

  Future<({PluginCatalog catalog, String stored})> _fetch(String url) async {
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

  /// Installs plugin [slug] of the repository [repoUrl] (a [PluginRepo.url]).
  /// Undo (`undoInstall`) is only for a [RepoPluginChange.installed] or
  /// [RepoPluginChange.revived] result, never for `updated`: that plugin was
  /// installed before and undo would uninstall it.
  Future<RepoPluginResult> install(String repoUrl, String slug) =>
      _installer.install(repoUrl, slug);

  /// Updates the plugin [installId] to its repository's catalog version.
  Future<RepoPluginResult> update(String installId) =>
      _installer.update(installId);

  /// Updates every plugin that has an update, one after the other; failures
  /// are outcomes. A call during a running one shares it.
  Future<List<RepoUpdateOutcome>> updateAll() => _installer.updateAll();

  /// Each plugin's outcome of [updateAll], as soon as it is known.
  Stream<RepoUpdateOutcome> get updateOutcomes => _installer.updateOutcomes;

  /// Install ids being updated right now, by [update] or [updateAll].
  Set<String> get updating => _installer.updating;

  /// Ends [updateOutcomes]. Call when the controller is dropped.
  Future<void> dispose() => _installer.dispose();

  int _now() => _clock().millisecondsSinceEpoch;
}

AddRepoFailure _failureOf(RepoFetchException error) => switch (error.kind) {
  RepoFetchErrorKind.network => AddRepoFailure.network,
  RepoFetchErrorKind.notFound => AddRepoFailure.notFound,
  RepoFetchErrorKind.tooLarge ||
  RepoFetchErrorKind.invalidCatalog => AddRepoFailure.badFormat,
  RepoFetchErrorKind.blockedAddress => switch (error.reason) {
    RepoAddressProblem.publicNeedsHttps => AddRepoFailure.publicNeedsHttps,
    RepoAddressProblem.invalidUrl ||
    RepoAddressProblem.userInfo => AddRepoFailure.invalidUrl,
    _ => AddRepoFailure.blockedAddress,
  },
};
