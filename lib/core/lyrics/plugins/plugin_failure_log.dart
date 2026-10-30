import 'dart:async';

import 'package:logging/logging.dart';

import '../online/lyrics_fetch_exception.dart';
import 'plugin_run_log.dart';

final _log = Logger('lyrics_plugin');

/// The one INFO line of the app log for a failed run: plugin name,
/// `installId`, script, failure kind, and the host (only) of an address that
/// was blocked. No song data, path, console line or stack.
String pluginFailureLogLine({
  required String pluginName,
  required String installId,
  required String script,
  required String kind,
  String? blockedHost,
}) {
  final name = pluginName.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ');
  final host = blockedHost == null ? '' : ' host=$blockedHost';
  return 'Lyrics plugin "$name" ($installId) $script failed: $kind$host';
}

/// Writes [pluginFailureLogLine] to the app log at INFO.
void logPluginFailure({
  required String pluginName,
  required String installId,
  required String script,
  required String kind,
  String? blockedHost,
}) => _log.info(
  pluginFailureLogLine(
    pluginName: pluginName,
    installId: installId,
    script: script,
    kind: kind,
    blockedHost: blockedHost,
  ),
);

/// Writes [event] to the plugin's log file and, when the run [failed], one
/// INFO line to the app log. The file write is not awaited: a slow disk never
/// delays a lookup. The host of a blocked address is that of the first
/// request the bridge marked blocked, hidden if it holds a config value.
void recordPluginRun(
  PluginRunLog log,
  PluginRunLogEvent event,
  Map<String, String> config, {
  required bool failed,
}) {
  unawaited(log.write(event, config: config));
  if (!failed) return;
  final blocked = event.kind == LyricsFetchKind.blockedHost.name
      ? event.requests.where((r) => r.blocked).firstOrNull?.host
      : null;
  logPluginFailure(
    pluginName: event.pluginName,
    installId: event.installId,
    script: event.script,
    kind: event.kind,
    blockedHost: blocked == null ? null : configValueHider(config)(blocked),
  );
}
