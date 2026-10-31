import '../../core/lyrics/plugins/package/plugin_package_problem.dart';
import '../../core/lyrics/plugins/repo/repo_operation_results.dart';
import '../../core/lyrics/plugins/store/plugin_install_outcome.dart';
import '../../l10n/l10n.dart';
import 'repo_error_text.dart';

/// Why a plugin package was refused, in the user's language. The detail
/// (entry name, manifest field, host, script file) is already cleaned by the
/// package reader.
String packageProblemText(AppLocalizations l10n, PluginPackageProblem p) {
  final detail = p.detail;
  final line = p.line;
  return switch (p.kind) {
    PluginPackageProblemKind.tooLarge => l10n.lyricsStoreProblemTooLarge,
    PluginPackageProblemKind.notZip => l10n.lyricsStoreProblemNotZip,
    PluginPackageProblemKind.unsafeEntry => l10n.lyricsStoreProblemUnsafeEntry(
      detail,
    ),
    PluginPackageProblemKind.tooManyEntries =>
      l10n.lyricsStoreProblemTooManyEntries,
    PluginPackageProblemKind.missingManifest =>
      l10n.lyricsStoreProblemMissingManifest,
    PluginPackageProblemKind.invalidManifest =>
      detail.isEmpty
          ? l10n.lyricsStoreProblemInvalidManifestPlain
          : l10n.lyricsStoreProblemInvalidManifest(detail),
    PluginPackageProblemKind.needsNewerApp =>
      l10n.lyricsStoreProblemNeedsNewerApp,
    PluginPackageProblemKind.wrongType => l10n.lyricsStoreProblemWrongType,
    PluginPackageProblemKind.badHost => l10n.lyricsStoreProblemBadHost(detail),
    PluginPackageProblemKind.missingScript =>
      l10n.lyricsStoreProblemMissingScript(detail),
    PluginPackageProblemKind.scriptError =>
      line == null
          ? l10n.lyricsStoreProblemScriptError(detail)
          : l10n.lyricsStoreProblemScriptErrorLine(detail, line),
    PluginPackageProblemKind.checkUnavailable =>
      l10n.lyricsStoreProblemCheckUnavailable,
  };
}

String _refusalText(AppLocalizations l10n, PluginUpdateRefusal reason) =>
    switch (reason) {
      PluginUpdateRefusal.notFromRepo => l10n.lyricsStoreFailNotFromRepo,
      PluginUpdateRefusal.olderVersion => l10n.lyricsStoreFailOlderVersion,
    };

/// The reason a repository install or update failed. Covers every
/// [RepoPluginFailure]; the details it carries (problem kind, fetch error,
/// refusal) refine the text.
String repoFailureText(AppLocalizations l10n, RepoPluginFailed failed) =>
    switch (failed.failure) {
      RepoPluginFailure.unknownRepo => l10n.lyricsStoreFailUnknownRepo,
      RepoPluginFailure.unknownEntry => l10n.lyricsStoreFailUnknownEntry,
      RepoPluginFailure.needsNewerApp => l10n.lyricsStoreProblemNeedsNewerApp,
      RepoPluginFailure.notFromRepo => l10n.lyricsStoreFailNotFromRepo,
      RepoPluginFailure.noNewerVersion => l10n.lyricsStoreFailNoNewerVersion,
      RepoPluginFailure.download => l10n.lyricsStoreFailDownload(
        failed.fetchError == null
            ? l10n.lyricsStoreLoadNetwork
            : downloadReasonText(l10n, failed.fetchError!),
      ),
      RepoPluginFailure.rejected =>
        failed.problem == null
            ? l10n.lyricsStoreFailRejected
            : packageProblemText(l10n, failed.problem!),
      RepoPluginFailure.catalogMismatch => l10n.lyricsStoreFailMismatch,
      RepoPluginFailure.refused =>
        failed.refusal == null
            ? l10n.lyricsStoreFailRejected
            : _refusalText(l10n, failed.refusal!),
      RepoPluginFailure.secretsUnavailable =>
        l10n.lyricsStoreFailSecretsUnavailable,
      RepoPluginFailure.gone => l10n.lyricsStoreFailGone,
      RepoPluginFailure.storage => l10n.lyricsStoreFailStorage,
    };

/// What a file install outcome tells the user: one line, or null when the
/// plugin was installed.
String? fileOutcomeText(
  AppLocalizations l10n,
  PluginInstallOutcome outcome,
) => switch (outcome) {
  PluginInstalled() => null,
  PluginInstallRejected(:final problem) => packageProblemText(l10n, problem),
  PluginInstallRefused(:final reason) => _refusalText(l10n, reason),
  PluginInstallSecretsUnavailable() => l10n.lyricsStoreFailSecretsUnavailable,
  PluginInstallGone() => l10n.lyricsStoreFailGone,
};

/// True when [failed] means "this app is too old for the plugin".
bool needsNewerApp(RepoPluginFailed failed) =>
    failed.failure == RepoPluginFailure.needsNewerApp ||
    failed.problem?.kind == PluginPackageProblemKind.needsNewerApp;
