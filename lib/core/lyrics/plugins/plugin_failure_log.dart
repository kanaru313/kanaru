import 'dart:async';

import 'package:logging/logging.dart';

import '../../plugin_runtime/plugin_runtime.dart';
import '../online/lyrics_fetch_exception.dart';
import 'package/plugin_config_field.dart';
import 'plugin_run_log.dart';

final _log = Logger('lyrics_plugin');

const _translateBlockedKind = 'blocked';

/// The one INFO line of the app log for a failed run: plugin name,
/// `installId`, script, failure kind, and the host (only) of an address that
/// was blocked. No song data, path, console line or stack.
String pluginFailureLogLine({
  required String pluginName,
  required String installId,
  required String script,
  required String kind,
  String? blockedHost,
  String label = 'Lyrics plugin',
}) {
  final name = pluginName.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ');
  final host = blockedHost == null ? '' : ' host=$blockedHost';
  return '$label "$name" ($installId) $script failed: $kind$host';
}

/// Writes [pluginFailureLogLine] to the app log at INFO.
void logPluginFailure({
  required String pluginName,
  required String installId,
  required String script,
  required String kind,
  String? blockedHost,
  String label = 'Lyrics plugin',
}) => _log.info(
  pluginFailureLogLine(
    pluginName: pluginName,
    installId: installId,
    script: script,
    kind: kind,
    blockedHost: blockedHost,
    label: label,
  ),
);

/// Writes [event] to the plugin's log file and, when the run [failed], one
/// INFO line to the app log. The file write is not awaited: a slow disk never
/// delays a lookup. The host of a blocked address is that of the first
/// request the bridge marked blocked, hidden if it holds a config value.
void recordPluginRun(
  PluginRunLog log,
  PluginRunLogEvent event,
  PluginConfigMap config, {
  List<PluginConfigField> schema = const [],
  required bool failed,
  String appLogLabel = 'Lyrics plugin',
}) {
  final typed = userEnteredConfig(schema, config);
  unawaited(log.write(event, config: typed));
  if (!failed) return;
  // Lyrics name this kind `blockedHost`, translate `blocked`.
  final blocked =
      (event.kind == LyricsFetchKind.blockedHost.name ||
          event.kind == _translateBlockedKind)
      ? event.requests.where((r) => r.blocked).firstOrNull?.host
      : null;
  logPluginFailure(
    pluginName: event.pluginName,
    installId: event.installId,
    script: event.script,
    kind: event.kind,
    blockedHost: blocked == null ? null : configValueHider(typed)(blocked),
    label: appLogLabel,
  );
}
