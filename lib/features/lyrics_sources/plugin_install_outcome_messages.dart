import '../../core/lyrics/plugins/lyrics_plugins_controller.dart';
import '../../core/lyrics/plugins/package/plugin_package_problem.dart';
import '../../l10n/l10n.dart';

/// Why a plugin package was refused, in the user's language. [detail] (an
/// entry name, a manifest field, a host or a script file, per kind) is
/// already cleaned by the package reader.
String pluginProblemMessage(AppLocalizations l10n, PluginPackageProblem p) {
  final detail = p.detail;
  final line = p.line;
  return switch (p.kind) {
    PluginPackageProblemKind.tooLarge => l10n.pluginProblemTooLarge,
    PluginPackageProblemKind.notZip => l10n.pluginProblemNotZip,
    PluginPackageProblemKind.unsafeEntry => l10n.pluginProblemUnsafeEntry(
      detail,
    ),
    PluginPackageProblemKind.tooManyEntries => l10n.pluginProblemTooManyEntries,
    PluginPackageProblemKind.missingManifest =>
      l10n.pluginProblemMissingManifest,
    PluginPackageProblemKind.invalidManifest =>
      detail.isEmpty
          ? l10n.pluginProblemInvalidManifestPlain
          : l10n.pluginProblemInvalidManifest(detail),
    PluginPackageProblemKind.needsNewerApp => l10n.pluginProblemNeedsNewerApp,
    PluginPackageProblemKind.wrongType => l10n.pluginProblemWrongType,
    PluginPackageProblemKind.badHost => l10n.pluginProblemBadHost(detail),
    PluginPackageProblemKind.missingScript => l10n.pluginProblemMissingScript(
      detail,
    ),
    PluginPackageProblemKind.scriptError =>
      line == null
          ? l10n.pluginProblemScriptError(detail)
          : l10n.pluginProblemScriptErrorLine(detail, line),
    PluginPackageProblemKind.checkUnavailable =>
      l10n.pluginProblemCheckUnavailable,
  };
}

/// What an install or update outcome tells the user, one line per reason, or
/// an empty list when it succeeded. Covers a refused package (every kind of
/// problem), a refused update, an unavailable keyring and a plugin that is
/// already gone.
List<String> pluginInstallOutcomeReasons(
  AppLocalizations l10n,
  PluginInstallOutcome outcome,
) => switch (outcome) {
  PluginInstalled() => const [],
  PluginInstallRejected(:final problem) => [
    pluginProblemMessage(l10n, problem),
  ],
  PluginInstallRefused(:final reason) => [
    switch (reason) {
      PluginUpdateRefusal.notFromRepo => l10n.pluginRefusedNotFromRepo,
      PluginUpdateRefusal.olderVersion => l10n.pluginRefusedOlderVersion,
    },
  ],
  PluginInstallSecretsUnavailable() => [l10n.pluginInstallSecretsUnavailable],
  PluginInstallGone() => [l10n.pluginInstallGone],
};
