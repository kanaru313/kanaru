import '../../core/sources/source_plugin_records.dart';

/// The host shown under the plugin's name: the first entry of its `hosts`
/// that is not a wildcard (`*.example.com`), or null when there is none.
String? displayHost(LyricsPluginRecord record) {
  for (final host in record.hosts) {
    if (!host.startsWith('*.')) return host;
  }
  return null;
}
