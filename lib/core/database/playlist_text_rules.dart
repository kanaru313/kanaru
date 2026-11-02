import 'package:flutter/widgets.dart' show StringCharacters;

/// Longest playlist name, in grapheme clusters (the unit a text field's
/// `maxLength` counts), so a counter in the UI and core never disagree.
const playlistNameMaxLength = 200;

/// Longest playlist description, in grapheme clusters.
const playlistDescriptionMaxLength = 2000;

/// C0 control characters (U+0000..U+001F) and DEL (U+007F).
final _controls = RegExp(r'[\x00-\x1F\x7F]');

/// Same, but keeping tab and line feed.
final _controlsKeepingBreaks = RegExp(r'[\x00-\x08\x0B-\x1F\x7F]');

/// [name] without control characters, trimmed.
String cleanPlaylistName(String name) => name.replaceAll(_controls, '').trim();

/// [description] without control characters other than `\n` and `\t`,
/// trimmed.
String cleanPlaylistDescription(String description) =>
    description.replaceAll(_controlsKeepingBreaks, '').trim();

/// Length of [text] in grapheme clusters.
int graphemeLength(String text) => text.characters.length;

/// [name] cut to [playlistNameMaxLength] graphemes. A trailing parenthesised
/// suffix such as " (copy)" survives: the text before it is shortened.
String capPlaylistName(String name) {
  if (graphemeLength(name) <= playlistNameMaxLength) return name;
  final suffix = RegExp(r' \([^()]*\)$').firstMatch(name)?.group(0) ?? '';
  final room = playlistNameMaxLength - graphemeLength(suffix);
  if (room <= 0) return name.characters.take(playlistNameMaxLength).toString();
  // The suffix match is on ASCII ' (' and ')', so the cut offset sits on a
  // code unit boundary; `characters` then cuts the base on grapheme borders.
  final base = name.substring(0, name.length - suffix.length);
  return '${base.characters.take(room).toString().trimRight()}$suffix';
}
