import '../../core/lyrics/plugins/package/plugin_package_problem.dart';
import '../../l10n/l10n.dart';

/// Why a plugin package was refused, in the user's language. [PluginPackageProblem.detail]
/// (an entry name, a manifest field, a host or a script file, per kind) is
/// already cleaned by the package reader.
String pluginProblemText(AppLocalizations l10n, PluginPackageProblem p) {
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
