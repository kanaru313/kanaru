import 'dart:convert';

import '../../database/library_database.dart';
import '../../database/lyrics_plugin_spec.dart';
import 'package/plugin_manifest.dart';
import 'store/plugin_config_schema_codec.dart';

/// Dart view of one `lyrics_plugins` row, with the hosts and the config form
/// already parsed. Removed records (only a name for saved lyrics) have
/// [isRemoved] set.
class LyricsPluginRecord {
  const LyricsPluginRecord({
    required this.installId,
    required this.name,
    this.author,
    this.description,
    required this.version,
    required this.apiVersion,
    required this.hosts,
    required this.config,
    required this.packageDir,
    required this.sourceKind,
    required this.sourceName,
    this.repoUrl,
    this.repoSlug,
    required this.installedAt,
    required this.updatedAt,
    this.removedAt,
  });

  factory LyricsPluginRecord.fromRow(LyricsPluginRow row) => LyricsPluginRecord(
    installId: row.installId,
    name: row.name,
    author: row.author,
    description: row.description,
    version: row.version,
    apiVersion: row.apiVersion,
    hosts: _hosts(row.hosts),
    config: decodePluginConfigSchema(row.configSchema),
    packageDir: row.packageDir,
    sourceKind: row.sourceKind == LyricsPluginSourceKind.repo.value
        ? LyricsPluginSourceKind.repo
        : LyricsPluginSourceKind.file,
    sourceName: row.sourceName,
    repoUrl: row.repoUrl,
    repoSlug: row.repoSlug,
    installedAt: row.installedAt,
    updatedAt: row.updatedAt,
    removedAt: row.removedAt,
  );

  final String installId;
  final String name;
  final String? author;
  final String? description;
  final int version;
  final int apiVersion;
  final List<String> hosts;

  /// The config form the package declares, in manifest order.
  final List<PluginConfigField> config;

  /// Directory of the current package, relative to the plugin root.
  final String packageDir;
  final LyricsPluginSourceKind sourceKind;
  final String sourceName;
  final String? repoUrl;
  final String? repoSlug;
  final int installedAt;

  /// Changes on every install, revive and update; a run keeps the value it
  /// began with to guard its storage write.
  final int updatedAt;
  final int? removedAt;

  bool get isRemoved => removedAt != null;

  /// The field named [key], or null.
  PluginConfigField? field(String key) {
    for (final field in config) {
      if (field.key == key) return field;
    }
    return null;
  }
}

List<String> _hosts(String json) {
  try {
    final value = jsonDecode(json);
    if (value is List) return List.unmodifiable(value.whereType<String>());
  } on FormatException {
    // Falls through: a host list this build cannot read counts as empty.
  }
  return const [];
}
