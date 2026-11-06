import 'dart:convert';

import '../lyrics/online/lyrics_http_request.dart';
import '../lyrics/plugins/package/plugin_text_clean.dart';
import '../lyrics/plugins/plugin_output_reader.dart' show PluginOutputException;
import 'source_models.dart';

export '../lyrics/plugins/plugin_output_reader.dart' show PluginOutputException;

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

/// Largest `next` of a page and largest stream `url`, in UTF-8 bytes.
const maxSourceTokenBytes = 8 * 1024;

/// Most headers a stream may ask for.
const maxSourceStreamHeaders = 20;

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
  final data = _decode(json);
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
  if (next != null && _bytes(next) > maxSourceTokenBytes) {
    notes?.add('"next" is larger than $maxSourceTokenBytes bytes');
    next = null;
  }
  if (next != null && (next.isEmpty || next == inputNext)) next = null;
  return SourceSearchPage(items: List.unmodifiable(items), next: next);
}

/// Reads the output JSON of `stream.js`:
/// `{url, headers, mimeType, bitrate?, expiresAtMs?}`. A `bitrate` or
/// `expiresAtMs` that is not a positive integer reads as unknown. Throws
/// [PluginOutputException] for a bad `url`, `headers` or `mimeType`.
SourceStream readSourceStreamOutput(String json) {
  final data = _decode(json);
  if (data is! Map) {
    throw const PluginOutputException('stream output must be an object');
  }
  final url = _streamUrl(data['url']);
  final headers = _streamHeaders(data['headers']);
  final mimeType = data['mimeType'];
  if (mimeType is! String || !_playableMime(mimeType)) {
    throw const PluginOutputException(
      '"mimeType" must be audio/*, video/webm or video/mp4',
    );
  }
  final expiresAtMs = _positiveInt(data['expiresAtMs']);
  return SourceStream(
    url: url,
    headers: Map.unmodifiable(headers),
    mimeType: mimeType,
    bitrate: _positiveInt(data['bitrate']),
    expiresAt: expiresAtMs == null || expiresAtMs > _maxEpochMs
        ? null
        : DateTime.fromMillisecondsSinceEpoch(expiresAtMs, isUtc: true),
  );
}

// The latest instant a DateTime holds.
const _maxEpochMs = 8640000000000000;

Object? _decode(String json) {
  try {
    return jsonDecode(json);
  } on FormatException {
    throw const PluginOutputException('the output is not valid JSON');
  }
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
  final rawTitle = item['title'];
  final title = rawTitle is String ? cleanPluginText(rawTitle) : '';
  if (title.isEmpty || title.runes.length > maxSourceTitleLength) {
    return (null, '"title" must be 1 to $maxSourceTitleLength characters');
  }
  final rawArtist = item['artist'];
  final artist = rawArtist is String ? cleanPluginText(rawArtist) : '';
  final ms = _positiveInt(item['durationMs']);
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

Uri _streamUrl(Object? value) {
  const problem = PluginOutputException(
    '"url" must be an absolute https URL of at most 8 KiB, without a port '
    'or user info',
  );
  if (value is! String || _bytes(value) > maxSourceTokenBytes) throw problem;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.hasPort ||
      _writesPort(value) ||
      uri.userInfo.isNotEmpty) {
    throw problem;
  }
  return uri;
}

/// [url] spells a port, even the default one, which [Uri] drops (so
/// `https://a.com:443/` has no `hasPort`).
bool _writesPort(String url) {
  final start = url.indexOf('//') + 2;
  var end = url.length;
  for (final mark in const ['/', '?', '#']) {
    final at = url.indexOf(mark, start);
    if (at >= 0 && at < end) end = at;
  }
  final authority = url.substring(start, end);
  final host = authority.substring(authority.lastIndexOf('@') + 1);
  return host.replaceAll(_ipv6Literal, '').contains(':');
}

final _ipv6Literal = RegExp(r'\[[^\]]*\]');

/// The headers to send: filtered like any plugin request header, then
/// without `range` and `if-range`, which the player decides.
Map<String, String> _streamHeaders(Object? value) {
  if (value == null) return const {};
  if (value is! Map || value.length > maxSourceStreamHeaders) {
    throw const PluginOutputException(
      '"headers" must be an object of at most $maxSourceStreamHeaders strings',
    );
  }
  final requested = <String, String>{};
  for (final MapEntry(:key, :value) in value.entries) {
    if (key is! String || value is! String) {
      throw const PluginOutputException('"headers" values must be strings');
    }
    requested[key] = value;
  }
  final Map<String, String> headers;
  try {
    headers = lyricsRequestHeaders(requested);
  } on LyricsRequestRejected {
    throw const PluginOutputException('"headers" has a bad name or value');
  }
  return headers
    ..remove('range')
    ..remove('if-range');
}

bool _playableMime(String value) {
  final type = value.split(';').first.trim().toLowerCase();
  return (type.startsWith('audio/') && type.length > 'audio/'.length) ||
      type == 'video/webm' ||
      type == 'video/mp4';
}

/// [value] as an integer above 0 (a whole double such as `5.0` counts), else
/// null.
int? _positiveInt(Object? value) {
  final int number;
  if (value is int) {
    number = value;
  } else if (value is double &&
      value.isFinite &&
      value == value.truncate() &&
      value.abs() < 9007199254740992.0) {
    number = value.toInt();
  } else {
    return null;
  }
  return number > 0 ? number : null;
}

int _bytes(String text) {
  // A UTF-16 unit is at least one byte and at most three.
  if (text.length * 3 <= maxSourceTokenBytes) return text.length;
  return utf8.encode(text).length;
}
