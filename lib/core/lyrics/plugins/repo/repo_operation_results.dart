import '../lyrics_plugin_record.dart';
import '../package/plugin_package_problem.dart';
import '../store/plugin_install_outcome.dart';
import 'plugin_repo.dart';
import 'repo_address_rules.dart';

/// Why adding a repository failed; the app shows each under the URL field.
enum AddRepoFailure {
  /// Not an `http` or `https` URL, or it carries a user name or password.
  invalidUrl,

  /// A public address over plain `http`.
  publicNeedsHttps,

  /// The same repository (normalized URL) is already added.
  duplicate,

  /// No connection, TLS failure, timeout, redirects or an HTTP error.
  network,

  /// The server answered 404 or 410.
  notFound,

  /// Not a catalog: bad JSON or shape, too large, or no usable entry.
  badFormat,

  /// Another address rule refused the address; see
  /// [AddRepoFailed.addressProblem].
  blockedAddress,

  /// The library database is unavailable or refused the write.
  storage,
}

sealed class AddRepoResult {
  const AddRepoResult();
}

/// The repository is stored. [pluginCount] is the number of valid entries.
class AddRepoAdded extends AddRepoResult {
  const AddRepoAdded({
    required this.url,
    required this.name,
    required this.pluginCount,
  });

  final String url;
  final String name;
  final int pluginCount;
}

class AddRepoFailed extends AddRepoResult {
  const AddRepoFailed(this.failure, {this.addressProblem});

  final AddRepoFailure failure;
  final RepoAddressProblem? addressProblem;
}

/// What became of one repository in a refresh.
class RepoRefreshResult {
  const RepoRefreshResult(this.url, this.error);

  final String url;

  /// Null when the catalog was fetched and stored.
  final RepoLoadError? error;
}

/// Why an install or an update did not happen. Nothing was changed.
enum RepoPluginFailure {
  /// The repository is not added (any more).
  unknownRepo,

  /// The stored catalog has no entry with that slug (or the plugin has no
  /// repo entry to update from).
  unknownEntry,

  /// The entry needs a newer Kanaru (`apiVersion`).
  needsNewerApp,

  /// Update only: the plugin was installed from a file.
  notFromRepo,

  /// Update only: the catalog version is not above the installed one.
  noNewerVersion,

  /// The download failed; see [RepoPluginFailed.fetchError].
  download,

  /// The package was refused; see [RepoPluginFailed.problem].
  rejected,

  /// The package's `version` or `hosts` differ from the catalog entry.
  catalogMismatch,

  /// The installer refused; see [RepoPluginFailed.refusal].
  refused,

  /// The secret store could not clear a removed plugin's secrets.
  secretsUnavailable,

  /// Update only: the plugin is missing or removed.
  gone,

  /// The library database or the plugin folder failed (closed database, full
  /// disk, permissions). Nothing usable was written.
  storage,
}

/// What an install or update did to the plugin.
enum RepoPluginChange {
  /// A new record. Undo (`LyricsPluginsController.undoInstall`) is for this.
  installed,

  /// A removed record of the same repo and slug came back under its old id.
  /// Undo is allowed: it removes the record again, as it was before.
  revived,

  /// A live plugin was replaced by another version (an update, or an install
  /// of a plugin that was already installed). Never offer Undo for this:
  /// `undoInstall` would uninstall the plugin the user already had, with its
  /// config, secrets and storage.
  updated,
}

sealed class RepoPluginResult {
  const RepoPluginResult();
}

/// Installed or updated; [record] comes from the package's own manifest.
class RepoPluginDone extends RepoPluginResult {
  const RepoPluginDone(this.record, this.change);

  final LyricsPluginRecord record;

  /// Offer Undo only when this is [RepoPluginChange.installed] or
  /// [RepoPluginChange.revived]; the wording ("installed" or "updated to v")
  /// follows it too.
  final RepoPluginChange change;
}

class RepoPluginFailed extends RepoPluginResult {
  const RepoPluginFailed(
    this.failure, {
    this.fetchError,
    this.problem,
    this.refusal,
    this.packageDeclared,
  });

  final RepoPluginFailure failure;
  final RepoLoadError? fetchError;
  final PluginPackageProblem? problem;
  final PluginUpdateRefusal? refusal;

  /// Set for [RepoPluginFailure.catalogMismatch]: what the downloaded package
  /// itself declares, to show next to what the catalog promised. The hosts
  /// already passed the host rules.
  final ({int version, List<String> hosts})? packageDeclared;
}

/// One plugin of an update-all run, in the order it was tried.
class RepoUpdateOutcome {
  const RepoUpdateOutcome(this.installId, this.name, this.result);

  final String installId;
  final String name;
  final RepoPluginResult result;
}
