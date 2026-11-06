import 'dart:convert';

import '../../../core/lyrics/plugins/package/plugin_number_text.dart';

/// A string that tells two payloads apart, for "is this already saved".
/// Never throws: a value JSON cannot hold (NaN, Infinity) falls back to its
/// text.
String pluginPayloadSignature(Object? payload) {
  try {
    return jsonEncode(payload);
  } on Object {
    return 'unencodable:$payload';
  }
}

/// An empty string: the way to remove a saved text.
bool pluginPayloadIsEmptyText(Object? payload) =>
    payload is String && payload.isEmpty;

/// An empty list or map: a value of its own.
bool pluginPayloadIsEmptyCollection(Object? payload) =>
    (payload is List && payload.isEmpty) || (payload is Map && payload.isEmpty);

/// Whether [payload] is, or holds, a number that is not finite.
bool pluginPayloadHasNonFinite(Object? payload) => switch (payload) {
  num() => !payload.isFinite,
  List() => payload.any(pluginPayloadHasNonFinite),
  _ => false,
};

/// [text] as a finite number (an int when [whole]); null when it is not one
/// (hex, `Infinity`, `NaN` and values past the double range included).
num? pluginParseFinite(String text, {bool whole = false}) =>
    parsePluginNumberText(text, whole: whole);
