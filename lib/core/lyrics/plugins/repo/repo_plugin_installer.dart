import 'dart:async';

import 'package:logging/logging.dart';

import '../../../database/library_database.dart';
import '../../../database/lyrics_plugin_queries.dart';
import '../lyrics_plugins_controller.dart';
import '../package/plugin_manifest.dart';
import '../package/plugin_manifest_parser.dart' show supportedPluginApiVersion;
import '../package/plugin_package_reader.dart';
import 'plugin_catalog.dart';
import 'plugin_repo.dart';
import 'plugin_repo_reader.dart';
import 'plugin_update_check.dart';
import 'repo_fetch_exception.dart';
import 'repo_http.dart';
import 'repo_operation_results.dart';

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

  /// Running installs (`i:<repo url>\n<slug>`) and updates (`u:<install id>`).
  final _inFlight = <String, Future<RepoPluginResult>>{};
  final _updatingIds = <String>{};
  Future<List<RepoUpdateOutcome>>? _updatingAll;
  final _outcomes = StreamController<RepoUpdateOutcome>.broadcast();

  /// Install ids being updated right now (by [update] or [updateAll]).
  Set<String> get updating => Set.unmodifiable(_updatingIds);

  /// Each plugin's outcome, as soon as [updateAll] finishes it.
  Stream<RepoUpdateOutcome> get updateOutcomes => _outcomes.stream;

  Future<void> dispose() => _outcomes.close();

  /// Installs plugin [slug] of the repository at [repoUrl]. A removed record
  /// of the same repo and slug is revived under its old id; a live one is
  /// updated (an older package is refused). [RepoPluginDone.change] tells
  /// which happened: Undo is for `installed` and `revived` only.
  Future<RepoPluginResult> install(String repoUrl, String slug) =>
      _shared('i:$repoUrl\n$slug', () => _install(repoUrl, slug));

  /// Updates the plugin [installId] to the version in its repository's
  /// catalog. No consent prompt, whatever changed.
  Future<RepoPluginResult> update(String installId) =>
      _shared('u:$installId', () => _update(installId), updatingId: installId);

  /// Updates every plugin that has an update, one after the other. A failed
  /// plugin is a failed outcome and the run goes on. A call made while
  /// another runs shares its result; outcomes also arrive on
  /// [updateOutcomes] one by one.
  Future<List<RepoUpdateOutcome>> updateAll() =>
      _updatingAll ??= _updateAll().whenComplete(() => _updatingAll = null);

  Future<RepoPluginResult> _shared(
    String key,
    Future<RepoPluginResult> Function() run, {
    String? updatingId,
  }) {
    final running = _inFlight[key];
    if (running != null) return running;
    if (updatingId != null) _updatingIds.add(updatingId);
    return _inFlight[key] = _guarded(run).whenComplete(() {
      _inFlight.remove(key);
      if (updatingId != null) _updatingIds.remove(updatingId);
    });
  }

  /// Maps what the typed steps do not (database, disk) to `storage`. Logs the
  /// error type only: a message may carry a path or an address.
  Future<RepoPluginResult> _guarded(
    Future<RepoPluginResult> Function() run,
  ) async {
    try {
      return await run();
    } on Object catch (error) {
      _log.warning(
        'Installing or updating a plugin failed: ${error.runtimeType}',
      );
      return const RepoPluginFailed(RepoPluginFailure.storage);
    }
  }

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

  Future<List<RepoUpdateOutcome>> _updateAll() async {
    final List<LyricsPluginRecord> due;
    try {
      final repos = {for (final r in await _repos()) r.url: r};
      due = [
        for (final row in await _db.watchLyricsPluginRecords().first)
          if (availableUpdate(LyricsPluginRecord.fromRow(row), repos) != null)
            LyricsPluginRecord.fromRow(row),
      ];
    } on Object catch (error) {
      _log.warning('Listing plugin updates failed: ${error.runtimeType}');
      return const [];
    }
    final outcomes = <RepoUpdateOutcome>[];
    for (final record in due) {
      final result = await update(record.installId);
      // Updated or removed by someone else since the list was made.
      if (result is RepoPluginFailed &&
          (result.failure == RepoPluginFailure.noNewerVersion ||
              result.failure == RepoPluginFailure.gone)) {
        continue;
      }
      final outcome = RepoUpdateOutcome(record.installId, record.name, result);
      outcomes.add(outcome);
      if (!_outcomes.isClosed) _outcomes.add(outcome);
    }
    return List.unmodifiable(outcomes);
  }

  /// Downloads the entry's zip and checks it, then hands the package to
  /// [write]. The zip is fetched with the stricter of the repository's
  /// stored class and a fresh look at its address ([RepoHttp.effectiveKind]),
  /// failing closed.
  Future<RepoPluginResult> _apply(
    PluginRepo repo,
    PluginCatalogEntry entry,
    Future<RepoPluginResult> Function(PluginPackage package) write,
  ) async {
    final stored = repo.kind;
    if (stored == null) {
      return const RepoPluginFailed(RepoPluginFailure.unknownRepo);
    }
    final RepoResponse download;
    try {
      final kind = await _http.effectiveKind(Uri.parse(repo.url), stored);
      download = await _http.fetchZip(entry.path, catalogKind: kind);
    } on RepoFetchException catch (error) {
      return RepoPluginFailed(
        RepoPluginFailure.download,
        fetchError: RepoLoadError.of(error),
      );
    }
    final read = await _reader.read(download.bytes);
    if (read is PluginPackageRejected) {
      return RepoPluginFailed(
        RepoPluginFailure.rejected,
        problem: read.problem,
      );
    }
    final package = (read as PluginPackageAccepted).package;
    if (!_matches(entry, package.manifest)) {
      return const RepoPluginFailed(RepoPluginFailure.catalogMismatch);
    }
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

  /// `version` equal and `hosts` equal as sets: what the user was shown in
  /// the store is what the package declares.
  bool _matches(PluginCatalogEntry entry, PluginManifest manifest) {
    final same =
        manifest.version == entry.version &&
        manifest.hosts.toSet().length == entry.hosts.toSet().length &&
        manifest.hosts.toSet().containsAll(entry.hosts);
    if (!same) _log.info('Package differs from its catalog entry');
    return same;
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
