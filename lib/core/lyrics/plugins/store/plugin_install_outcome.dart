import '../lyrics_plugin_record.dart';
import '../package/plugin_package_problem.dart';

/// How installing or updating from bytes or a file ended.
sealed class PluginInstallOutcome {
  const PluginInstallOutcome();
}

class PluginInstalled extends PluginInstallOutcome {
  const PluginInstalled(this.record);

  final LyricsPluginRecord record;
}

/// The package was refused; nothing was written.
class PluginInstallRejected extends PluginInstallOutcome {
  const PluginInstallRejected(this.problem);

  final PluginPackageProblem problem;
}

/// An update found no live plugin with that id.
class PluginInstallGone extends PluginInstallOutcome {
  const PluginInstallGone();
}

/// Why an update was refused.
enum PluginUpdateRefusal {
  /// The plugin was installed from a file; only repo plugins update.
  notFromRepo,

  /// The package's version is lower than the installed one (equal is fine).
  olderVersion,
}

/// An update was refused for [reason]; nothing changed.
class PluginInstallRefused extends PluginInstallOutcome {
  const PluginInstallRefused(this.reason);

  final PluginUpdateRefusal reason;
}

/// The secret store could not delete the secrets of a removed plugin that
/// the install would have revived; try again later. Nothing changed.
class PluginInstallSecretsUnavailable extends PluginInstallOutcome {
  const PluginInstallSecretsUnavailable();
}

/// Thrown by the installer for [PluginInstallRefused].
class PluginUpdateRefusedException implements Exception {
  const PluginUpdateRefusedException(this.reason);

  final PluginUpdateRefusal reason;
}

/// Thrown by the installer for [PluginInstallSecretsUnavailable].
class PluginSecretsUnavailableException implements Exception {
  const PluginSecretsUnavailableException();
}
