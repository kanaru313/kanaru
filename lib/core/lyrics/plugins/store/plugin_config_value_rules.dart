import '../package/plugin_config_field.dart';
import '../package/plugin_text_clean.dart';
import 'plugin_config_values.dart';

final _whitespace = RegExp(r'\s');

/// The text between `://` and the first `/`, `?` or `#`, or null without
/// `://`. The parsed authority drops an empty user name, so `https://@host`
/// is caught on the raw text; an `@` later in the URL is not user info.
String? _authorityOf(String value) {
  final scheme = value.indexOf('://');
  if (scheme < 0) return null;
  final start = scheme + 3;
  var end = start;
  while (end < value.length) {
    final c = value[end];
    if (c == '/' || c == '?' || c == '#') break;
    end++;
  }
  return value.substring(start, end);
}

/// https only, with a host and no credentials, as the plugin `fetch` needs.
PluginValueProblem? pluginUrlProblem(String value) {
  if (value.runes.length > pluginConfigMaxText) {
    return PluginValueProblem.tooLong;
  }
  if (_whitespace.hasMatch(value)) return PluginValueProblem.badUrl;
  final uri = Uri.tryParse(value);
  if (value != cleanPluginText(value)) return PluginValueProblem.badUrl;
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      _authorityOf(value)?.contains('@') != false) {
    return PluginValueProblem.badUrl;
  }
  return null;
}

/// 1 to 100 code points with no control or format characters and no outer
/// space; `__proto__` is refused. Case matters.
bool pluginMapKeyIsValid(String key) =>
    key.isNotEmpty &&
    key.runes.length <= pluginConfigMaxMapKey &&
    key == cleanPluginText(key) &&
    key != '__proto__';
