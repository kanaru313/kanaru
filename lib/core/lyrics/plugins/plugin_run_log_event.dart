import 'plugin_fetch_bridge.dart';

/// The `kind` of a run that did not fail but printed to the console.
const pluginRunOkKind = 'ok';

/// The `kind` of a run that was cancelled; never written.
const pluginRunAbandonedKind = 'abandoned';

/// Shortest config value that is hidden; shorter ones would hide ordinary
/// words in a message.
const _minMaskedLength = 4;

/// One line of a plugin's log file. `query` is the run input (song data
/// included; the file stays on this device and is never attached to a bug
/// report by itself). Config values must not be in any field except through
/// [PluginRunLog.write], which hides them in [message], [stack], [console]
/// and the request paths.
class PluginRunLogEvent {
  const PluginRunLogEvent({
    required this.time,
    required this.installId,
    required this.pluginName,
    required this.version,
    required this.script,
    required this.query,
    required this.kind,
    this.message = '',
    this.stack,
    this.console = const [],
    this.requests = const [],
  });

  final DateTime time;
  final String installId;
  final String pluginName;
  final String version;

  /// `search.js` or `lyrics.js`.
  final String script;

  /// A JSON-encodable value: the input map, a text or a remote id.
  final Object? query;

  /// The failure name (see `pluginFailureName`), or [pluginRunOkKind].
  final String kind;
  final String message;
  final String? stack;
  final List<String> console;
  final List<PluginRequestRecord> requests;

  /// The JSON object of the log line, with every [config] value hidden.
  Map<String, Object?> toJson(Map<String, String> config) {
    final hide = configValueHider(config);
    return {
      'ts': time.toUtc().toIso8601String(),
      'installId': installId,
      'pluginName': pluginName,
      'version': version,
      'script': script,
      'query': _hideDeep(query, hide),
      'kind': kind,
      'message': hide(message),
      'stack': stack == null ? null : hide(stack!),
      'console': [for (final line in console) hide(line)],
      'requests': [
        for (final r in requests)
          {...r.toJson(), 'host': hide(r.host), 'path': hide(r.path)},
      ],
    };
  }
}

/// A function that replaces every [config] value of at least four characters
/// in a text with `***`. A value is also hidden in the forms a script or a
/// URL gives it: the percent-encoded component and the percent-encoded whole
/// address. Longer values go first, so overlapping secrets are hidden whole.
String Function(String) configValueHider(Map<String, String> config) {
  final secrets = <String>{
    for (final value in config.values)
      if (value.length >= _minMaskedLength) ...[
        value,
        Uri.encodeComponent(value),
        Uri.encodeFull(value),
      ],
  }.toList()..sort((a, b) => b.length.compareTo(a.length));
  return (text) =>
      secrets.fold(text, (masked, secret) => masked.replaceAll(secret, '***'));
}

// Hides config values in every string of a JSON-like value (the run input).
Object? _hideDeep(Object? value, String Function(String) hide) =>
    switch (value) {
      String() => hide(value),
      List() => [for (final v in value) _hideDeep(v, hide)],
      Map() => {for (final e in value.entries) e.key: _hideDeep(e.value, hide)},
      _ => value,
    };
