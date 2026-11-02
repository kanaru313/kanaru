import '../../../database/language_tags.dart';

/// The JSON wildcard that marks a plugin as global (any language).
const pluginLanguagesGlobal = '*';

/// Most items of a `languages` list that are read; a longer list is ignored.
const _maxListLength = 50;

/// Most distinct languages kept for one plugin.
const _maxKept = 20;

final _validKey = RegExp(r'^[a-z]{2,3}$');

/// Keys that say nothing about a language: undetermined, no linguistic
/// content, several languages.
const _unusableKeys = {'und', 'zxx', 'mul'};

/// Reads the optional `languages` field of a plugin manifest or catalog entry
/// into normalized language keys (see `languageKey`: `vi` becomes `vie`).
///
/// An empty result means "global": the plugin serves any language. The field
/// never makes a plugin invalid, so this never throws: a value that is not a
/// list, a list over 50 items, or a list with no usable item is global.
/// Items that are not strings, are empty, are `und`, `zxx` or `mul`, or are
/// not a 2 to 3 letter code are skipped; repeats are removed; at most 20 are
/// kept. A `*` item makes the whole plugin global.
List<String> parsePluginLanguages(Object? value) {
  if (value is! List || value.length > _maxListLength) return const [];
  final keys = <String>[];
  for (final item in value) {
    if (item is! String) continue;
    final text = item.trim();
    if (text == pluginLanguagesGlobal) return const [];
    if (text.isEmpty) continue;
    final key = languageKey(text);
    if (!_validKey.hasMatch(key) || _unusableKeys.contains(key)) continue;
    if (keys.contains(key) || keys.length >= _maxKept) continue;
    keys.add(key);
  }
  return List.unmodifiable(keys);
}
