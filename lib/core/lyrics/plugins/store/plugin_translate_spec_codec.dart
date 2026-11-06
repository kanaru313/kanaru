import 'dart:convert';

import '../package/plugin_translate_spec.dart';

/// The text stored in `lyrics_plugins.translate_spec`: the `translate` block
/// of the manifest, as [PluginTranslateSpec.toJson] writes it.
String encodePluginTranslateSpec(PluginTranslateSpec spec) =>
    jsonEncode(spec.toJson());

/// Reads [text] back with the manifest's own parser, so a stored block obeys
/// the same limits. Null for null, text that is not JSON, or a block the
/// parser refuses.
PluginTranslateSpec? decodePluginTranslateSpec(String? text) {
  if (text == null) return null;
  try {
    return parsePluginTranslateSpec(jsonDecode(text)).spec;
  } on FormatException {
    return null;
  } on PluginTranslateSpecError {
    return null;
  }
}
