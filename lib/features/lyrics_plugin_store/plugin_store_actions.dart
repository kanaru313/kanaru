import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugins_provider.dart';
import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import '../../core/lyrics/plugins/repo/plugin_catalog.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'install_problem_dialog.dart';
import 'catalog_mismatch_lines.dart';
import 'install_problem_text.dart';
import 'plugin_store_messages.dart';
import 'plugin_store_providers.dart';
import 'store_uninstall_dialog.dart';

final _log = Logger('lyrics_plugin_store');

/// What a plugin install or update was about, for the messages.
typedef _Subject = ({String name, String? repoName, PluginCatalogEntry? entry});

/// The things the store screens do: install, update, uninstall, install from
/// a file, refresh. Built from a widget's [context]; everything the work
/// needs later (providers, messenger, texts) is taken at once, so a screen
/// that closes meanwhile does not break it. A dialog is shown only while the
/// screen is still there; otherwise a failure becomes a snackbar.
class PluginStoreActions {
  PluginStoreActions(BuildContext context)
    : _context = context,
      _container = ProviderScope.containerOf(context),
      _messages = StoreMessages(context),
      _l10n = context.l10n;

  final BuildContext _context;
  final ProviderContainer _container;
  final StoreMessages _messages;
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

  /// Fetches one repository again.
  Future<void> refreshOne(String url) async {
    try {
      await _repos?.refresh(url);
    } on Object catch (error, stackTrace) {
      _log.warning('Refreshing a repository failed', error, stackTrace);
    }
  }

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
      _messages.error(_l10n.lyricsStoreFailStorage);
      return;
    } finally {
      pending.end(key);
    }
    await _handle(
      result,
      (name: name, repoName: repoName, entry: entry),
      () => install(
        repoUrl: repoUrl,
        slug: slug,
        name: name,
        repoName: repoName,
        entry: entry,
      ),
    );
  }

  /// Updates the plugin [installId] to its catalog version.
  Future<void> update({
    required String installId,
    required String name,
    String? repoName,
    PluginCatalogEntry? entry,
  }) async {
    final repos = _repos;
    if (repos == null) return;
    final RepoPluginResult result;
    try {
      result = await repos.update(installId);
    } on Object catch (error, stackTrace) {
      _log.warning('Updating a plugin failed', error, stackTrace);
      _messages.error(_l10n.lyricsStoreFailStorage);
      return;
    }
    await _handle(
      result,
      (name: name, repoName: repoName, entry: entry),
      () => update(
        installId: installId,
        name: name,
        repoName: repoName,
        entry: entry,
      ),
    );
  }

  /// Updates every plugin that has an update.
  Future<void> updateAll() async {
    final repos = _repos;
    if (repos == null) return;
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
      _messages.error(_l10n.lyricsStoreFailStorage);
    }
  }

  /// Asks, then uninstalls [record].
  Future<void> uninstall(LyricsPluginRecord record) async {
    if (!await confirmStoreUninstall(_context, record)) return;
    final plugins = _container.read(lyricsPluginsControllerProvider);
    if (plugins == null) return;
    try {
      await plugins.uninstall(record.installId);
      _messages.message(_l10n.lyricsStoreUninstalled(record.name));
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
      _messages.error(_l10n.lyricsStoreFailStorage);
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
    await _showProblem(subject, [reason]);
  }

  Future<void> _handle(
    RepoPluginResult result,
    _Subject subject,
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
        await _failed(failed, subject, retry);
    }
  }

  Future<void> _failed(
    RepoPluginFailed failed,
    _Subject subject,
    Future<void> Function() retry,
  ) async {
    // An install that joined a running update, or an update that was not
    // needed: nothing went wrong.
    if (failed.failure == RepoPluginFailure.noNewerVersion) return;
    final repoLine = subject.repoName == null
        ? subject.name
        : _l10n.lyricsStoreInstallFailedRepo(subject.name, subject.repoName!);
    if (needsNewerApp(failed)) {
      if (_context.mounted) {
        await showNeedsNewerAppDialog(_context, subject.name);
      } else {
        _messages.error(_l10n.lyricsStoreNeedsNewerBody(subject.name));
      }
      return;
    }
    if (failed.failure == RepoPluginFailure.catalogMismatch) {
      if (!_context.mounted) {
        _messages.error(_l10n.lyricsStoreFailMismatch);
        return;
      }
      final again = await showCatalogMismatchDialog(
        _context,
        subject: repoLine,
        differences: mismatchLines(_l10n, failed, subject.entry),
      );
      if (again) {
        await refreshAll();
        await retry();
      }
      return;
    }
    await _showProblem(repoLine, [repoFailureText(_l10n, failed)]);
  }

  Future<void> _showProblem(String subject, List<String> reasons) async {
    if (_context.mounted) {
      await showInstallProblemDialog(
        _context,
        subject: subject,
        reasons: reasons,
      );
    } else {
      _messages.error(reasons.join('\n'));
    }
  }
}
