import '../../core/lyrics/plugins/repo/plugin_catalog.dart';
import '../../core/lyrics/plugins/repo/repo_operation_results.dart';
import '../../l10n/l10n.dart';

/// The lines of the "Gói không khớp danh sách" dialog: what the catalog said
/// and what the package declares, only where they differ. A generic line
/// when the details are not known.
List<String> mismatchLines(
  AppLocalizations l10n,
  RepoPluginFailed failed,
  PluginCatalogEntry? entry,
) {
  final declared = failed.packageDeclared;
  if (declared == null || entry == null) {
    return [l10n.lyricsStoreMismatchGeneric];
  }
  final lines = <String>[
    if (declared.version != entry.version)
      l10n.lyricsStoreMismatchVersion(entry.version, declared.version),
    if (!_sameHosts(declared.hosts, entry.hosts))
      l10n.lyricsStoreMismatchHosts(
        entry.hosts.join(', '),
        declared.hosts.join(', '),
      ),
  ];
  return lines.isEmpty ? [l10n.lyricsStoreMismatchGeneric] : lines;
}

bool _sameHosts(List<String> a, List<String> b) =>
    a.length == b.length && a.toSet().containsAll(b);
