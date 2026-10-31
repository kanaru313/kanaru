import '../../core/lyrics/plugins/package/plugin_package_problem.dart';
import '../../core/lyrics/plugins/repo/plugin_repo.dart';
import '../../core/lyrics/plugins/repo/repo_fetch_exception.dart';
import '../../core/lyrics/plugins/repo/repo_operation_results.dart';
import '../../core/lyrics/plugins/store/plugin_install_outcome.dart';
import '../../l10n/l10n.dart';
import 'plugin_install_outcome_messages.dart';

/// One line saying why an update from the repository did not happen, for the
/// failure snackbar of the update banner. Package refusals reuse the install
/// outcome texts; the other failures have their own line.
String? pluginUpdateFailureReason(AppLocalizations l10n, RepoPluginFailed f) {
  final problem = f.problem;
  final refusal = f.refusal;
  switch (f.failure) {
    case RepoPluginFailure.rejected when problem != null:
      return _outcomeReason(l10n, PluginInstallRejected(problem));
    case RepoPluginFailure.refused when refusal != null:
      return _outcomeReason(l10n, PluginInstallRefused(refusal));
    case RepoPluginFailure.needsNewerApp:
      return _outcomeReason(
        l10n,
        PluginInstallRejected(
          const PluginPackageProblem(PluginPackageProblemKind.needsNewerApp),
        ),
      );
    case RepoPluginFailure.rejected:
    case RepoPluginFailure.refused:
      return l10n.lyricsStoreFailRejected;
    case RepoPluginFailure.download:
      return l10n.lyricsStoreFailDownload(_downloadReason(l10n, f.fetchError));
    case RepoPluginFailure.catalogMismatch:
      return l10n.lyricsStoreFailMismatch;
    case RepoPluginFailure.storage:
      return l10n.lyricsStoreFailStorage;
    case RepoPluginFailure.secretsUnavailable:
      return l10n.lyricsStoreFailSecretsUnavailable;
    case RepoPluginFailure.gone:
      return l10n.lyricsStoreFailGone;
    case RepoPluginFailure.unknownRepo:
      return l10n.lyricsStoreFailUnknownRepo;
    case RepoPluginFailure.unknownEntry:
      return l10n.lyricsStoreFailUnknownEntry;
    case RepoPluginFailure.notFromRepo:
      return l10n.lyricsStoreFailNotFromRepo;
    case RepoPluginFailure.noNewerVersion:
      return l10n.lyricsStoreFailNoNewerVersion;
  }
}

String? _outcomeReason(AppLocalizations l10n, PluginInstallOutcome outcome) =>
    pluginInstallOutcomeReasons(l10n, outcome).firstOrNull;

String _downloadReason(AppLocalizations l10n, RepoLoadError? error) =>
    switch (error?.kind) {
      null || RepoFetchErrorKind.network => l10n.lyricsStoreLoadNetwork,
      RepoFetchErrorKind.notFound => l10n.lyricsStoreLoadNotFound,
      RepoFetchErrorKind.tooLarge => l10n.lyricsStoreFailPackageTooLarge,
      RepoFetchErrorKind.invalidCatalog => l10n.lyricsStoreLoadInvalid,
      RepoFetchErrorKind.blockedAddress => l10n.lyricsStoreLoadBlocked,
    };
