import '../lyrics/plugins/package/plugin_text_clean.dart';
import 'source_models.dart';
import 'source_output_reader.dart';

/// Most items one search page keeps; the rest is dropped.
const maxSourceItems = 200;

/// Longest item id, in code points.
const maxSourceItemIdLength = 200;

/// Longest title and artist, in code points, after cleaning.
const maxSourceTitleLength = 300;
const maxSourceArtistLength = 200;

/// Longest believed duration (24 h).
const maxSourceDurationMs = 86400000;

/// Longest `artworkUrl` or `webUrl`, in characters.
const maxSourceLinkLength = 2000;

final _control = RegExp(r'\p{Cc}', unicode: true);

/// Reads the output JSON of `search.js`: `{items: [...], next}`. An item that
/// breaks a rule is dropped with a reason in [notes] (`item #4: …`, numbered
/// from 1); at most [maxSourceItems] are kept. A `next` equal to
/// [inputNext] (the plugin would loop), longer than [maxSourceTokenBytes] or
/// empty reads as none. Throws [PluginOutputException] for any other shape.
SourceSearchPage readSourceSearchOutput(
  String json, {
  String? inputNext,
  List<String>? notes,
}) {
  final data = decodeSourceOutput(json);
  if (data is! Map) {
    throw const PluginOutputException('search output must be an object');
  }
  final list = data['items'];
  if (list is! List) {
    throw const PluginOutputException('"items" must be an array');
  }
  final rawNext = data['next'];
  if (rawNext != null && rawNext is! String) {
    throw const PluginOutputException('"next" must be a string or null');
  }
  final items = <SourceItem>[];
  var over = 0;
  for (var i = 0; i < list.length; i++) {
    final (item, problem) = _readItem(list[i]);
    if (problem != null) {
      notes?.add('item #${i + 1}: $problem');
    } else if (items.length < maxSourceItems) {
      items.add(item!);
    } else {
      over++;
    }
  }
  if (over > 0) notes?.add('$over items over the limit of $maxSourceItems');
  String? next = rawNext as String?;
  if (next != null && sourceTokenBytes(next) > maxSourceTokenBytes) {
    notes?.add('"next" is larger than $maxSourceTokenBytes bytes');
    next = null;
  }
  if (next != null && (next.isEmpty || next == inputNext)) next = null;
  return SourceSearchPage(items: List.unmodifiable(items), next: next);
}

/// The item, or the reason it is dropped.
(SourceItem?, String?) _readItem(Object? item) {
  if (item is! Map) return (null, 'must be an object');
  final id = item['id'];
  if (id is! String ||
      id.isEmpty ||
      id.runes.length > maxSourceItemIdLength ||
      _control.hasMatch(id)) {
    return (
      null,
      '"id" must be 1 to $maxSourceItemIdLength characters without control '
          'characters',
    );
  }
  // A proxy URL cannot carry them: URI parsing removes dot segments.
  if (id == '.' || id == '..') return (null, '"id" must not be "." or ".."');
  final rawTitle = item['title'];
  final title = rawTitle is String ? cleanPluginText(rawTitle) : '';
  if (title.isEmpty || title.runes.length > maxSourceTitleLength) {
    return (null, '"title" must be 1 to $maxSourceTitleLength characters');
  }
  final rawArtist = item['artist'];
  final artist = rawArtist is String ? cleanPluginText(rawArtist) : '';
  final ms = sourcePositiveInt(item['durationMs']);
  return (
    SourceItem(
      id: id,
      title: title,
      artist: artist.isEmpty || artist.runes.length > maxSourceArtistLength
          ? null
          : artist,
      duration: ms == null || ms > maxSourceDurationMs
          ? null
          : Duration(milliseconds: ms),
      artworkUrl: _link(item['artworkUrl']),
      webUrl: _link(item['webUrl']),
    ),
    null,
  );
}

/// [value] when it is an absolute `https` URL of at most
/// [maxSourceLinkLength] characters without user info; else null.
String? _link(Object? value) {
  if (value is! String || value.length > maxSourceLinkLength) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return value;
}
