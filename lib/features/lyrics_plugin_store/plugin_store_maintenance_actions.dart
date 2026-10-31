import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugins_provider.dart';
import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'install_problem_text.dart';
import 'plugin_store_failures.dart';
import 'plugin_store_messages.dart';
import 'plugin_store_providers.dart';
import 'store_uninstall_dialog.dart';

final _log = Logger('lyrics_plugin_store');

/// The store actions that are not one install or update: refreshing,
/// "update all", uninstall and install from a file. Used through
/// `PluginStoreActions`.
class StoreMaintenanceActions {
  StoreMaintenanceActions(
    this._context,
    this._container,
    this._messages,
    this._failures,
  ) : _l10n = _context.l10n;

  final BuildContext _context;
  final ProviderContainer _container;
  final StoreMessages _messages;
  final StoreFailures _failures;
  final AppLocalizations _l10n;

  LyricsPluginReposController? get _repos =>
      _container.read(lyricsPluginReposControllerProvider);

  /// Fetches every repository and lets icons that failed be tried again.
  Future<void> refreshAll() async {
    final repos = _repos;
    if (repos == null) return;
    try {
      await repos.refreshAll();
      _container.read(repoIconCacheProvider).clearFailures();
    } on Object catch (error, stackTrace) {
      _log.warning('Refreshing the repositories failed', error, stackTrace);
    }
  }

  /// Fetches one repository again; its icons that failed are tried again too.
  Future<void> refreshOne(String url) async {
    try {
      await _repos?.refresh(url);
      _container.read(repoIconCacheProvider).clearFailures();
    } on Object catch (error, stackTrace) {
      _log.warning('Refreshing a repository failed', error, stackTrace);
    }
  }

  /// Updates every plugin that has an update. A second call while one runs
  /// does nothing.
  Future<void> updateAll() async {
    final repos = _repos;
    final pending = _container.read(
      pluginStorePendingInstallsProvider.notifier,
    );
    if (repos == null || !pending.begin(pendingUpdateAllKey)) return;
    try {
      final outcomes = await repos.updateAll();
      var done = 0;
      var failed = 0;
      for (final outcome in outcomes) {
        switch (outcome.result) {
          case RepoPluginDone():
            done++;
          case RepoPluginFailed(:final failure):
            if (failure != RepoPluginFailure.noNewerVersion) failed++;
        }
      }
      if (done == 0 && failed == 0) return;
      _messages.message(
        failed == 0
            ? _l10n.lyricsStoreUpdatedAll(done)
            : _l10n.lyricsStoreUpdatedAllPartial(done, failed),
        kind: failed == 0 ? AppSnackBarKind.success : AppSnackBarKind.warning,
      );
    } on Object catch (error, stackTrace) {
      _log.warning('Updating all plugins failed', error, stackTrace);
      _messages.error(_l10n.lyricsStoreFailUnexpected);
    } finally {
      pending.end(pendingUpdateAllKey);
    }
  }

  /// Asks, then uninstalls [record]. "Uninstalled" only when something was.
  Future<void> uninstall(LyricsPluginRecord record) async {
    if (!await confirmStoreUninstall(_context, record)) return;
    final plugins = _container.read(lyricsPluginsControllerProvider);
    if (plugins == null) return;
    try {
      final result = await plugins.uninstall(record.installId);
      switch (result) {
        case LyricsPluginUninstall.markedRemoved:
        case LyricsPluginUninstall.deleted:
          _messages.message(_l10n.lyricsStoreUninstalled(record.name));
        case LyricsPluginUninstall.missing:
        case LyricsPluginUninstall.alreadyRemoved:
          _messages.message(
            _l10n.lyricsStoreAlreadyGone(record.name),
            kind: AppSnackBarKind.info,
          );
      }
    } on Object catch (error, stackTrace) {
      _log.warning('Uninstalling a plugin failed', error, stackTrace);
      _messages.error(_l10n.lyricsStoreUninstallFailed(record.name));
    }
  }

  /// Asks for a zip and installs it as a new plugin.
  Future<void> installFromFile() async {
    final String? path;
    try {
      path = await _container.read(pluginZipPickerProvider)();
    } on Object catch (error, stackTrace) {
      _log.warning('Picking a plugin file failed', error, stackTrace);
      return;
    }
    final plugins = _container.read(lyricsPluginsControllerProvider);
    if (path == null || plugins == null) return;
    final name = path.split(RegExp(r'[\\/]')).last;
    final PluginInstallOutcome outcome;
    try {
      outcome = await plugins.installFromFile(path);
    } on Object catch (error, stackTrace) {
      _log.warning('Installing a plugin file failed', error, stackTrace);
      _messages.error(_l10n.lyricsStoreFailUnexpected);
      return;
    }
    if (outcome case PluginInstalled(:final record)) {
      _messages.installed(record);
      return;
    }
    final reason = fileOutcomeText(_l10n, outcome) ?? '';
    final subject = outcome is PluginInstallRejected
        ? _l10n.lyricsStoreInstallFailedFile(name)
        : name;
    await _failures.problem(subject, [reason]);
  }
}
