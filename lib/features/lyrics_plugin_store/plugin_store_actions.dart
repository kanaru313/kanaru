import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugins_provider.dart';
import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import '../../core/lyrics/plugins/repo/plugin_catalog.dart';
import '../../l10n/l10n.dart';
import 'plugin_store_failures.dart';
import 'plugin_store_maintenance_actions.dart';
import 'plugin_store_messages.dart';
import 'plugin_store_providers.dart';

final _log = Logger('lyrics_plugin_store');

/// The things the store screens do: install, update, uninstall, install from
/// a file, refresh. Built from a widget's [context]; everything the work
/// needs later (providers, messenger, texts) is taken at once, so a screen
/// that closes meanwhile does not break it. A dialog is shown only while the
/// screen is still there; otherwise a failure becomes a snackbar.
class PluginStoreActions {
  factory PluginStoreActions(BuildContext context) {
    final container = ProviderScope.containerOf(context);
    final messages = StoreMessages(context);
    final failures = StoreFailures(context, messages);
    return PluginStoreActions._(
      container,
      messages,
      failures,
      StoreMaintenanceActions(context, container, messages, failures),
      context.l10n,
    );
  }

  PluginStoreActions._(
    this._container,
    this._messages,
    this._failures,
    this._maintenance,
    this._l10n,
  );

  final ProviderContainer _container;
  final StoreMessages _messages;
  final StoreFailures _failures;
  final StoreMaintenanceActions _maintenance;
  final AppLocalizations _l10n;

  LyricsPluginReposController? get _repos =>
      _container.read(lyricsPluginReposControllerProvider);

  Future<void> refreshAll() => _maintenance.refreshAll();

  Future<void> refreshOne(String url) => _maintenance.refreshOne(url);

  Future<void> updateAll() => _maintenance.updateAll();

  Future<void> uninstall(LyricsPluginRecord record) =>
      _maintenance.uninstall(record);

  Future<void> installFromFile() => _maintenance.installFromFile();

  /// Installs plugin [slug] of [repoUrl] now (on, last in priority).
  Future<void> install({
    required String repoUrl,
    required String slug,
    required String name,
    String? repoName,
    PluginCatalogEntry? entry,
  }) async {
    final repos = _repos;
    final pending = _container.read(
      pluginStorePendingInstallsProvider.notifier,
    );
    final key = pendingInstallKey(repoUrl, slug);
    if (repos == null || !pending.begin(key)) return;
    final RepoPluginResult result;
    try {
      result = await repos.install(repoUrl, slug);
    } on Object catch (error, stackTrace) {
      _log.warning('Installing a plugin failed', error, stackTrace);
      _messages.error(_l10n.lyricsStoreFailUnexpected);
      return;
    } finally {
      pending.end(key);
    }
    await _handle(
      result,
      (name: name, repoName: repoName, entry: entry),
      () => _refreshThen(
        repoUrl,
        slug,
        _subjectLine(name, repoName),
        (fresh) => install(
          repoUrl: repoUrl,
          slug: slug,
          name: name,
          repoName: repoName,
          entry: fresh,
        ),
      ),
    );
  }

  /// Updates the plugin [installId] to its catalog version. [repoUrl] and
  /// [slug] name its catalog entry, so a retry after a mismatch can read the
  /// refreshed entry.
  Future<void> update({
    required String installId,
    required String name,
    String? repoName,
    PluginCatalogEntry? entry,
    String? repoUrl,
    String? slug,
  }) async {
    final repos = _repos;
    if (repos == null) return;
    final RepoPluginResult result;
    try {
      result = await repos.update(installId);
    } on Object catch (error, stackTrace) {
      _log.warning('Updating a plugin failed', error, stackTrace);
      _messages.error(_l10n.lyricsStoreFailUnexpected);
      return;
    }
    Future<void> again(PluginCatalogEntry? fresh) => update(
      installId: installId,
      name: name,
      repoName: repoName,
      entry: fresh,
      repoUrl: repoUrl,
      slug: slug,
    );
    await _handle(
      result,
      (name: name, repoName: repoName, entry: entry),
      () => repoUrl == null || slug == null
          ? _refreshAllThen(() => again(entry))
          : _refreshThen(repoUrl, slug, _subjectLine(name, repoName), again),
    );
  }

  Future<void> _handle(
    RepoPluginResult result,
    StoreSubject subject,
    Future<void> Function() retry,
  ) async {
    switch (result) {
      case RepoPluginDone(:final record, :final change):
        if (change == RepoPluginChange.updated) {
          _messages.message(
            _l10n.lyricsStoreUpdated(record.name, record.version),
          );
        } else {
          _messages.installed(record);
        }
      case RepoPluginFailed failed:
        await _failures.failed(failed, subject, retry);
    }
  }

  String _subjectLine(String name, String? repoName) => repoName == null
      ? name
      : _l10n.lyricsStoreInstallFailedRepo(name, repoName);

  Future<void> _refreshAllThen(Future<void> Function() run) async {
    await _maintenance.refreshAll();
    await run();
  }

  /// Fetches [repoUrl] again, reads the entry [slug] from the new catalog and
  /// runs [run] with it. When the repository or the entry is gone now, says
  /// so instead of trying with the old entry.
  Future<void> _refreshThen(
    String repoUrl,
    String slug,
    String subjectLine,
    Future<void> Function(PluginCatalogEntry fresh) run,
  ) async {
    await _maintenance.refreshOne(repoUrl);
    PluginCatalogEntry? fresh;
    try {
      final repos = await _repos?.watchRepos().first;
      for (final repo in repos ?? const <PluginRepo>[]) {
        if (repo.url == repoUrl) fresh = repo.entry(slug);
      }
    } on Object catch (error, stackTrace) {
      _log.warning('Reading the refreshed catalog failed', error, stackTrace);
      _messages.error(_l10n.lyricsStoreFailUnexpected);
      return;
    }
    if (fresh == null) {
      await _failures.problem(subjectLine, [_l10n.lyricsStoreFailUnknownEntry]);
      return;
    }
    await run(fresh);
  }
}
