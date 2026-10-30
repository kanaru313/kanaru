import 'dart:async';

import 'package:logging/logging.dart';

import '../../../database/library_database.dart';
import '../../../database/lyrics_plugin_queries.dart';
import '../lyrics_plugins_controller.dart';
import '../package/plugin_package_reader.dart';
import 'plugin_repo.dart';
import 'plugin_repo_reader.dart';
import 'repo_address_rules.dart';
import 'repo_fetch_exception.dart';
import 'repo_http.dart';
import 'repo_operation_results.dart';
import 'repo_plugin_installer.dart';
import 'repo_refresh_runner.dart';
import 'repo_url.dart';

export 'plugin_repo.dart' show PluginRepo, RepoLoadError;
export 'repo_operation_results.dart';
export 'repo_refresh_runner.dart' show repoRefreshParallelism;

final _log = Logger('lyrics_plugin_repos');

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
    _refresher = RepoRefreshRunner(
      db: _db,
      http: _http,
      reader: _reader,
      now: _now,
      isAdding: _adds.containsKey,
    );
  }

  final LibraryDatabase _db;
  final RepoHttp _http;
  final DateTime Function() _clock;
  final _reader = PluginRepoReader();
  late final RepoPluginInstaller _installer;
  late final RepoRefreshRunner _refresher;

  /// Repositories being added, by address: a second add shares the first, and
  /// a refresh leaves them alone.
  final _adds = <String, Future<AddRepoResult>>{};

  /// The repositories, oldest first, with their last good catalog.
  Stream<List<PluginRepo>> watchRepos() =>
      _db.watchLyricsPluginRepos().map(_reader.readAll);

  /// Adds the repository at [input] after fetching its catalog once. A
  /// failure after the row was inserted removes it again. Two calls for one
  /// address at the same time share the first one's result. A repository
  /// removed while it was being added is `storage` (nothing was stored).
  Future<AddRepoResult> add(String input) {
    final url = normalizeRepoUrl(input);
    if (url == null) {
      return Future.value(const AddRepoFailed(AddRepoFailure.invalidUrl));
    }
    return _adds[url] ??= _add(url).whenComplete(() {
      _adds.remove(url);
    });
  }

  Future<AddRepoResult> _add(String url) async {
    var inserted = false;
    var stored = false;
    try {
      if ((await _db.watchLyricsPluginRepos().first).any((r) => r.url == url)) {
        return const AddRepoFailed(AddRepoFailure.duplicate);
      }
      final fetched = await _refresher.fetch(url);
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
      if (saved == LyricsPluginWrite.skipped) {
        // The row was removed under us: nothing is stored.
        return const AddRepoFailed(AddRepoFailure.storage);
      }
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
  Future<List<RepoRefreshResult>> refreshAll() => _refresher.refreshAll();

  /// Refreshes one repository, like [refreshAll] does for each. Shares the
  /// fetch already running for [url]. Null when [url] is not added, is being
  /// added, or was removed meanwhile.
  Future<RepoRefreshResult?> refresh(String url) => _refresher.refresh(url);

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

  /// The [updating] set each time it changes (read [updating] for the value
  /// before the first event). Empty again when every started update ended,
  /// also those that failed or were skipped. For the UI: show a spinner on
  /// the rows in it.
  Stream<Set<String>> get updatingChanges => _installer.updatingChanges;

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
