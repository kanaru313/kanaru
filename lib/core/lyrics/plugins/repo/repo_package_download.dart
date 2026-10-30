import 'package:logging/logging.dart';

import '../package/plugin_manifest.dart';
import '../package/plugin_package_reader.dart';
import 'plugin_catalog.dart';
import 'plugin_repo.dart';
import 'repo_fetch_exception.dart';
import 'repo_http.dart';
import 'repo_operation_results.dart';

final _log = Logger('lyrics_plugin_repos');

/// A downloaded package that passed the file-install checks and matches its
/// catalog entry, or the failure that stopped it.
typedef RepoPackageOutcome = ({
  PluginPackage? package,
  RepoPluginFailed? failed,
});

/// Downloads the zip of [entry] and checks it. The zip is fetched with the
/// stricter of the repository's stored class and a fresh look at its address
/// ([RepoHttp.effectiveKind]), failing closed.
Future<RepoPackageOutcome> downloadRepoPackage(
  RepoHttp http,
  PluginPackageReader reader,
  PluginRepo repo,
  PluginCatalogEntry entry,
) async {
  final stored = repo.kind;
  if (stored == null) {
    return (
      package: null,
      failed: const RepoPluginFailed(RepoPluginFailure.unknownRepo),
    );
  }
  final RepoResponse download;
  try {
    final kind = await http.effectiveKind(Uri.parse(repo.url), stored);
    download = await http.fetchZip(entry.path, catalogKind: kind);
  } on RepoFetchException catch (error) {
    return (
      package: null,
      failed: RepoPluginFailed(
        RepoPluginFailure.download,
        fetchError: RepoLoadError.of(error),
      ),
    );
  }
  final read = await reader.read(download.bytes);
  if (read is PluginPackageRejected) {
    return (
      package: null,
      failed: RepoPluginFailed(
        RepoPluginFailure.rejected,
        problem: read.problem,
      ),
    );
  }
  final package = (read as PluginPackageAccepted).package;
  if (!_matches(entry, package.manifest)) {
    return (
      package: null,
      failed: RepoPluginFailed(
        RepoPluginFailure.catalogMismatch,
        packageDeclared: (
          version: package.manifest.version,
          hosts: List.unmodifiable(package.manifest.hosts),
        ),
      ),
    );
  }
  return (package: package, failed: null);
}

/// `version` equal and `hosts` equal as sets: what the user was shown in the
/// store is what the package declares.
bool _matches(PluginCatalogEntry entry, PluginManifest manifest) {
  final same =
      manifest.version == entry.version &&
      manifest.hosts.toSet().length == entry.hosts.toSet().length &&
      manifest.hosts.toSet().containsAll(entry.hosts);
  if (!same) _log.info('Package differs from its catalog entry');
  return same;
}
