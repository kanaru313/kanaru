import 'dart:async';

import 'package:logging/logging.dart';

import '../../../database/library_database.dart';
import '../../../database/lyrics_plugin_queries.dart';
import '../lyrics_plugins_controller.dart';
import '../package/plugin_manifest_parser.dart' show supportedPluginApiVersion;
import '../package/plugin_package_reader.dart';
import 'plugin_catalog.dart';
import 'plugin_repo.dart';
import 'plugin_repo_reader.dart';
import 'plugin_update_check.dart';
import 'repo_http.dart';
import 'repo_operation_results.dart';
import 'repo_package_download.dart';
import 'repo_run_tracker.dart';
import 'repo_update_all.dart';

final _log = Logger('lyrics_plugin_repos');

/// Installs and updates plugins from the catalogs of added repositories.
/// A package is downloaded, read by the same checks as a file install, and
/// compared with its catalog entry before anything is written; what gets
/// stored always comes from the package's own manifest. The write itself is
/// the plugins controller's, so it shares its queue and its rules.
///
/// No error escapes: every failure is a [RepoPluginFailed]. A call for a
/// plugin that is already being installed or updated shares the running one
/// (one download, one write), so a double tap or an update during "update
/// all" changes the plugin once.
class RepoPluginInstaller {
  RepoPluginInstaller({
    required this._db,
    required this._plugins,
    required this._reader,
    required this._http,
    required this._repoReader,
  });

  final LibraryDatabase _db;
  final LyricsPluginsController _plugins;
  final PluginPackageReader _reader;
  final RepoHttp _http;
  final PluginRepoReader _repoReader;

  final _runs = RepoRunTracker();
  Future<List<RepoUpdateOutcome>>? _updatingAll;
  final _outcomes = StreamController<RepoUpdateOutcome>.broadcast();

  /// Install ids being updated right now (by [update], [updateAll], or an
  /// install that turns out to update a live plugin).
  Set<String> get updating => _runs.updating;

  /// The [updating] set each time it changes. Every started id is removed
  /// again, also when the plugin was skipped or its update failed.
  Stream<Set<String>> get updatingChanges => _runs.updatingChanges;

  /// Each plugin's outcome, as soon as [updateAll] finishes it.
  Stream<RepoUpdateOutcome> get updateOutcomes => _outcomes.stream;

  Future<void> dispose() async {
    await _outcomes.close();
    await _runs.dispose();
  }

  /// Installs plugin [slug] of the repository at [repoUrl]. A removed record
  /// of the same repo and slug is revived under its old id; a live one is
  /// updated (an older package is refused). [RepoPluginDone.change] tells
  /// which happened: Undo is for `installed` and `revived` only.
  Future<RepoPluginResult> install(String repoUrl, String slug) async {
    // A live record of this repo and slug makes the install an update of that
    // plugin, so it shares the run (and the `updating` entry) of update().
    String? liveId;
    try {
      final before = await _db.lyricsPluginByRepo(repoUrl, slug);
      if (before != null && before.removedAt == null) liveId = before.installId;
    } on Object catch (error) {
      _log.warning('Reading a plugin failed: ${error.runtimeType}');
      return const RepoPluginFailed(RepoPluginFailure.storage);
    }
    return liveId == null
        ? _runs.share(
            'i:$repoUrl\n$slug',
            _guard(() => _install(repoUrl, slug)),
          )
        : _runs.share(
            'u:$liveId',
            _guard(() => _install(repoUrl, slug)),
            updatingId: liveId,
          );
  }

  /// Updates the plugin [installId] to the version in its repository's
  /// catalog. No consent prompt, whatever changed.
  Future<RepoPluginResult> update(String installId) => _runs.share(
    'u:$installId',
    _guard(() => _update(installId)),
    updatingId: installId,
  );

  /// Updates every plugin that has an update, one after the other. A failed
  /// plugin is a failed outcome and the run goes on. A call made while
  /// another runs shares its result; outcomes also arrive on
  /// [updateOutcomes] one by one.
  Future<List<RepoUpdateOutcome>> updateAll() =>
      _updatingAll ??= _updateAll().whenComplete(() => _updatingAll = null);

  /// Maps what the typed steps do not (database, disk) to `storage`. Logs the
  /// error type only: a message may carry a path or an address.
  Future<RepoPluginResult> Function() _guard(
    Future<RepoPluginResult> Function() run,
  ) => () async {
    try {
      return await run();
    } on Object catch (error) {
      _log.warning(
        'Installing or updating a plugin failed: ${error.runtimeType}',
      );
      return const RepoPluginFailed(RepoPluginFailure.storage);
    }
  };

  Future<RepoPluginResult> _install(String repoUrl, String slug) async {
    final repo = await _repo(repoUrl);
    final catalog = repo?.catalog;
    if (repo == null || catalog == null) {
      return const RepoPluginFailed(RepoPluginFailure.unknownRepo);
    }
    final entry = repo.entry(slug);
    if (entry == null) {
      return const RepoPluginFailed(RepoPluginFailure.unknownEntry);
    }
    if (entry.apiVersion > supportedPluginApiVersion) {
      return const RepoPluginFailed(RepoPluginFailure.needsNewerApp);
    }
    final source = PluginInstallSource.repo(
      name: repo.name,
      repoUrl: repoUrl,
      repoSlug: slug,
    );
    return _apply(repo, entry, (package) async {
      final before = await _db.lyricsPluginByRepo(repoUrl, slug);
      final change = before == null
          ? RepoPluginChange.installed
          : before.removedAt != null
          ? RepoPluginChange.revived
          : RepoPluginChange.updated;
      return RepoPluginDone(
        await _plugins.installPackage(package, source),
        change,
      );
    });
  }

  Future<RepoPluginResult> _update(String installId) async {
    final row = await _db.lyricsPluginById(installId);
    if (row == null || row.removedAt != null) {
      return const RepoPluginFailed(RepoPluginFailure.gone);
    }
    final record = LyricsPluginRecord.fromRow(row);
    final url = record.repoUrl;
    final slug = record.repoSlug;
    if (url == null || slug == null) {
      return const RepoPluginFailed(RepoPluginFailure.notFromRepo);
    }
    final repo = await _repo(url);
    final entry = repo?.entry(slug);
    if (repo == null || entry == null) {
      return RepoPluginFailed(
        repo == null
            ? RepoPluginFailure.unknownRepo
            : RepoPluginFailure.unknownEntry,
      );
    }
    if (entry.apiVersion > supportedPluginApiVersion) {
      return const RepoPluginFailed(RepoPluginFailure.needsNewerApp);
    }
    if (availableUpdate(record, {url: repo}) == null) {
      return const RepoPluginFailed(RepoPluginFailure.noNewerVersion);
    }
    return _apply(repo, entry, (package) async {
      final updated = await _plugins.updatePackage(installId, package);
      return updated == null
          ? const RepoPluginFailed(RepoPluginFailure.gone)
          : RepoPluginDone(updated, RepoPluginChange.updated);
    });
  }

  Future<List<RepoUpdateOutcome>> _updateAll() => runUpdateAll(
    listDue: () async {
      final repos = {for (final r in await _repos()) r.url: r};
      return [
        for (final row in await _db.watchLyricsPluginRecords().first)
          if (availableUpdate(LyricsPluginRecord.fromRow(row), repos) != null)
            LyricsPluginRecord.fromRow(row),
      ];
    },
    update: update,
    emit: (outcome) {
      if (!_outcomes.isClosed) _outcomes.add(outcome);
    },
  );

  /// Downloads and checks the entry's zip, then hands the package to [write].
  Future<RepoPluginResult> _apply(
    PluginRepo repo,
    PluginCatalogEntry entry,
    Future<RepoPluginResult> Function(PluginPackage package) write,
  ) async {
    final outcome = await downloadRepoPackage(_http, _reader, repo, entry);
    final package = outcome.package;
    if (package == null) return outcome.failed!;
    try {
      return await write(package);
    } on PluginUpdateRefusedException catch (refused) {
      return RepoPluginFailed(
        RepoPluginFailure.refused,
        refusal: refused.reason,
      );
    } on PluginSecretsUnavailableException {
      return const RepoPluginFailed(RepoPluginFailure.secretsUnavailable);
    }
  }

  /// Reads only the row of [url]; other catalogs are not decoded.
  Future<PluginRepo?> _repo(String url) async {
    for (final row in await _db.watchLyricsPluginRepos().first) {
      if (row.url == url) return _repoReader.read(row);
    }
    return null;
  }

  Future<List<PluginRepo>> _repos() async =>
      _repoReader.readAll(await _db.watchLyricsPluginRepos().first);
}
