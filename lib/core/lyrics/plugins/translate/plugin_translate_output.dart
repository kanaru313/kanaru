import 'dart:convert';

import '../../../lyrics_translation/translation_language.dart';
import '../plugin_output_reader.dart';

/// One translated line: its [text] and the language the plugin says the
/// source was in, when it said a usable one.
typedef PluginTranslatedLine = ({String text, String? detected});

// A BCP 47 style tag: `en`, `pt-BR`, `zh-Hant-TW`.
final _languageTag = RegExp(r'^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8}){0,3}$');

// C0 and C1 controls, and the bidi overrides and isolates that could make a
// line display as something else.
final _unsafeChars = RegExp(
  r'[\u0000-\u001F\u007F-\u009F\u202A-\u202E\u2066-\u2069]',
);
final _newlines = RegExp(r'[\r\n\u0085\u2028\u2029]+');
final _tabs = RegExp(r'\t+');

/// Reads the output of `translate.js` for [sources] (the lines that were
/// sent) into exactly as many lines, or throws [PluginOutputException].
///
/// * the data is a JSON array with one object per source line, each with a
///   string `text`; `detected` is optional and kept only when it is a
///   language tag (else dropped with a note);
/// * every text loses controls and bidi overrides, its newlines become one
///   space, and it may be at most `4 x source length + 200` characters;
/// * more than half of the non-blank source lines coming back empty is a
///   failure (a safety filter that blanked the answer must not be saved);
/// * a `detected` naming the [target] language on a line whose text changed
///   is dropped (a model labelling its own output would otherwise mark the
///   song as already in the target language).
///
/// [notes] receives one short reason per dropped `detected`.
List<PluginTranslatedLine> readTranslateOutput(
  String json,
  List<String> sources,
  String target,
  List<String> notes,
) {
  final Object? data;
  try {
    data = jsonDecode(json);
  } on FormatException {
    throw const PluginOutputException('translate output is not valid JSON');
  }
  if (data is! List) {
    throw const PluginOutputException('translate output must be an array');
  }
  if (data.length != sources.length) {
    throw const PluginOutputException(
      'translate output must have one item per line',
    );
  }
  final targetBase = baseLanguageOf(target);
  final lines = <PluginTranslatedLine>[];
  var blank = 0;
  var empty = 0;
  var droppedDetected = false;
  for (var i = 0; i < data.length; i++) {
    final item = data[i];
    final text = item is Map ? item['text'] : null;
    if (text is! String) {
      throw PluginOutputException('item #${i + 1}: "text" must be a string');
    }
    final clean = text
        .replaceAll(_newlines, ' ')
        .replaceAll(_tabs, ' ')
        .replaceAll(_unsafeChars, '')
        .trim();
    final source = sources[i];
    if (clean.length > 4 * source.length + 200) {
      throw PluginOutputException('item #${i + 1}: "text" is too long');
    }
    if (source.trim().isNotEmpty) {
      blank++;
      if (clean.isEmpty) empty++;
    }
    var detected = item is Map ? item['detected'] : null;
    if (detected != null &&
        (detected is! String || !_languageTag.hasMatch(detected))) {
      droppedDetected = true;
      detected = null;
    }
    if (detected is String &&
        baseLanguageOf(detected) == targetBase &&
        clean != source.trim()) {
      droppedDetected = true;
      detected = null;
    }
    lines.add((text: clean, detected: detected as String?));
  }
  if (empty * 2 > blank) {
    throw const PluginOutputException('most translated lines are empty');
  }
  if (droppedDetected) notes.add('detected');
  return lines;
}
