import '../../../database/lyrics_plugin_spec.dart';
import '../lyrics_plugin_record.dart';
import '../package/plugin_manifest_parser.dart' show supportedPluginApiVersion;
import 'plugin_catalog.dart';
import 'plugin_repo.dart';

/// The catalog entry that [record] can be updated to, or null. Only a live
/// plugin from a repo that is still added updates; the entry must have a
/// higher `version` and an `apiVersion` this app understands. Plugins from a
/// file never update.
PluginCatalogEntry? availableUpdate(
  LyricsPluginRecord record,
  Map<String, PluginRepo> reposByUrl,
) {
  if (record.isRemoved || record.sourceKind != LyricsPluginSourceKind.repo) {
    return null;
  }
  final url = record.repoUrl;
  final slug = record.repoSlug;
  if (url == null || slug == null) return null;
  final entry = reposByUrl[url]?.entry(slug);
  if (entry == null) return null;
  if (entry.apiVersion > supportedPluginApiVersion) return null;
  return entry.version > record.version ? entry : null;
}
