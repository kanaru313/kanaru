import '../lyrics/online/lyrics_http_request.dart';
import 'source_models.dart';
import 'source_output_reader.dart';

/// Most headers a stream may ask for.
const maxSourceStreamHeaders = 20;

/// Reads the output JSON of `stream.js`:
/// `{url, headers, mimeType, bitrate?, expiresAtMs?}`. A `bitrate` or
/// `expiresAtMs` that is not a positive integer reads as unknown. Throws
/// [PluginOutputException] for a bad `url`, `headers` or `mimeType`.
SourceStream readSourceStreamOutput(String json) {
  final data = decodeSourceOutput(json);
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
  final expiresAtMs = sourcePositiveInt(data['expiresAtMs']);
  return SourceStream(
    url: url,
    headers: Map.unmodifiable(headers),
    mimeType: mimeType,
    bitrate: sourcePositiveInt(data['bitrate']),
    expiresAt: expiresAtMs == null || expiresAtMs > _maxEpochMs
        ? null
        : DateTime.fromMillisecondsSinceEpoch(expiresAtMs, isUtc: true),
  );
}

// The latest instant a DateTime holds.
const _maxEpochMs = 8640000000000000;

Uri _streamUrl(Object? value) {
  const problem = PluginOutputException(
    '"url" must be an absolute https URL of at most 8 KiB, without a port '
    'or user info',
  );
  if (value is! String || sourceTokenBytes(value) > maxSourceTokenBytes) {
    throw problem;
  }
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
