import '../../../lyrics_translation/translation_language.dart';

/// Most chunk and language limits a translate plugin may declare. The floors
/// stop a plugin from splitting one song into hundreds of billed runs.
const translateMaxLinesRange = (min: 10, max: 200);
const translateMaxCharsRange = (min: 1000, max: 20000);

/// The longest a translate run may take, whatever the plugin declares.
const translateTimeoutCapSec = 90;
const translateDefaultMaxLines = 50;
const translateDefaultMaxChars = 4000;
const translateDefaultTimeoutSec = 15;

const _maxLanguageEntries = 200;

/// The `translate` block of a translate plugin's `plugin.json`: the target
/// languages it supports and how much one run may carry.
class PluginTranslateSpec {
  const PluginTranslateSpec({
    required this.languages,
    this.maxLines = translateDefaultMaxLines,
    this.maxChars = translateDefaultMaxChars,
    this.timeoutSec = translateDefaultTimeoutSec,
  });

  /// Codes of `translationLanguages` the plugin translates into.
  final List<String> languages;

  /// Most lines in one run.
  final int maxLines;

  /// Most characters of lyrics in one run.
  final int maxChars;

  /// Wall time of one run, already clamped to [translateTimeoutCapSec].
  final int timeoutSec;

  /// The block as it is written back to `plugin.json`.
  Map<String, Object?> toJson() => {
    'languages': languages,
    'maxLines': maxLines,
    'maxChars': maxChars,
    'timeoutSec': timeoutSec,
  };
}

/// What [parsePluginTranslateSpec] found wrong: the dotted field name.
class PluginTranslateSpecError implements Exception {
  const PluginTranslateSpecError(this.field);

  final String field;
}

/// Parses the `translate` block. Unknown language codes are dropped (their
/// number is returned in [droppedLanguages]); `timeoutSec` above the host cap
/// is clamped, not refused. Throws [PluginTranslateSpecError] naming
/// `translate.<field>`.
({PluginTranslateSpec spec, int droppedLanguages}) parsePluginTranslateSpec(
  Object? value,
) {
  if (value is! Map<String, dynamic>) {
    throw const PluginTranslateSpecError('translate');
  }
  final raw = value['languages'];
  if (raw is! List || raw.isEmpty || raw.length > _maxLanguageEntries) {
    throw const PluginTranslateSpecError('translate.languages');
  }
  final languages = <String>[];
  var dropped = 0;
  for (final item in raw) {
    if (item is! String) {
      throw const PluginTranslateSpecError('translate.languages');
    }
    if (translationLanguageFor(item) == null || languages.contains(item)) {
      dropped++;
    } else {
      languages.add(item);
    }
  }
  if (languages.isEmpty) {
    throw const PluginTranslateSpecError('translate.languages');
  }
  final timeout = _int(
    value['timeoutSec'],
    'timeoutSec',
    1,
    600,
    translateDefaultTimeoutSec,
  );
  return (
    spec: PluginTranslateSpec(
      languages: List.unmodifiable(languages),
      maxLines: _int(
        value['maxLines'],
        'maxLines',
        translateMaxLinesRange.min,
        translateMaxLinesRange.max,
        translateDefaultMaxLines,
      ),
      maxChars: _int(
        value['maxChars'],
        'maxChars',
        translateMaxCharsRange.min,
        translateMaxCharsRange.max,
        translateDefaultMaxChars,
      ),
      timeoutSec: timeout > translateTimeoutCapSec
          ? translateTimeoutCapSec
          : timeout,
    ),
    droppedLanguages: dropped,
  );
}

int _int(Object? value, String field, int min, int max, int fallback) {
  if (value == null) return fallback;
  if (value is! int || value < min || value > max) {
    throw PluginTranslateSpecError('translate.$field');
  }
  return value;
}
