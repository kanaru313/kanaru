import '../../core/lyrics/plugins/lyrics_plugins_controller.dart';
import '../../core/lyrics/plugins/package/plugin_package_problem.dart';
import '../../core/lyrics/plugins/repo/plugin_repo.dart';
import '../../core/lyrics/plugins/repo/repo_fetch_exception.dart';
import '../../core/lyrics/plugins/repo/repo_operation_results.dart';
import '../../core/lyrics/plugins/store/plugin_install_outcome.dart';
import '../../l10n/l10n.dart';
import 'plugin_problem_text.dart';

String _refusalText(AppLocalizations l10n, PluginUpdateRefusal reason) =>
    switch (reason) {
      PluginUpdateRefusal.notFromRepo => l10n.pluginRefusedNotFromRepo,
      PluginUpdateRefusal.olderVersion => l10n.pluginRefusedOlderVersion,
    };

/// Why a package download failed, as a short phrase. A null [error] means the
/// connection itself failed.
String pluginDownloadReasonText(AppLocalizations l10n, RepoLoadError? error) =>
    switch (error?.kind) {
      null || RepoFetchErrorKind.network => l10n.lyricsStoreLoadNetwork,
      RepoFetchErrorKind.notFound => l10n.lyricsStoreLoadNotFound,
      RepoFetchErrorKind.tooLarge => l10n.lyricsStoreFailPackageTooLarge,
      RepoFetchErrorKind.invalidCatalog => l10n.lyricsStoreLoadInvalid,
      RepoFetchErrorKind.blockedAddress => l10n.lyricsStoreLoadBlocked,
    };

/// The reason a repository install or update failed. Covers every
/// [RepoPluginFailure]; the details it carries (problem kind, fetch error,
/// refusal) refine the text.
String repoPluginFailureText(AppLocalizations l10n, RepoPluginFailed failed) =>
    switch (failed.failure) {
      RepoPluginFailure.unknownRepo => l10n.lyricsStoreFailUnknownRepo,
      RepoPluginFailure.unknownEntry => l10n.lyricsStoreFailUnknownEntry,
      RepoPluginFailure.needsNewerApp => l10n.pluginProblemNeedsNewerApp,
      RepoPluginFailure.notFromRepo => l10n.pluginRefusedNotFromRepo,
      RepoPluginFailure.noNewerVersion => l10n.lyricsStoreFailNoNewerVersion,
      RepoPluginFailure.download => l10n.lyricsStoreFailDownload(
        pluginDownloadReasonText(l10n, failed.fetchError),
      ),
      RepoPluginFailure.rejected =>
        failed.problem == null
            ? l10n.lyricsStoreFailRejected
            : pluginProblemText(l10n, failed.problem!),
      RepoPluginFailure.catalogMismatch => l10n.lyricsStoreFailMismatch,
      RepoPluginFailure.refused =>
        failed.refusal == null
            ? l10n.lyricsStoreFailRejected
            : _refusalText(l10n, failed.refusal!),
      RepoPluginFailure.secretsUnavailable =>
        l10n.pluginInstallSecretsUnavailable,
      RepoPluginFailure.gone => l10n.pluginInstallGone,
      RepoPluginFailure.storage => l10n.lyricsStoreFailStorage,
    };

/// What an install outcome tells the user: one line, or null when the plugin
/// was installed.
String? pluginOutcomeText(
  AppLocalizations l10n,
  PluginInstallOutcome outcome,
) => switch (outcome) {
  PluginInstalled() => null,
  PluginInstallRejected(:final problem) => pluginProblemText(l10n, problem),
  PluginInstallRefused(:final reason) => _refusalText(l10n, reason),
  PluginInstallSecretsUnavailable() => l10n.pluginInstallSecretsUnavailable,
  PluginInstallGone() => l10n.pluginInstallGone,
};

/// True when [failed] means "this app is too old for the plugin".
bool needsNewerApp(RepoPluginFailed failed) =>
    failed.failure == RepoPluginFailure.needsNewerApp ||
    failed.problem?.kind == PluginPackageProblemKind.needsNewerApp;
