import 'dart:typed_data';

/// Largest response body read, in bytes.
const lyricsMaxResponseBytes = 4 * 1024 * 1024;

/// Largest request body a source may send, in bytes.
const lyricsMaxRequestBytes = 256 * 1024;

/// A request a source asks `LyricsHttp.send` to make. `method` is `GET` or
/// `POST` (lower or upper case); [body] only goes with `POST`. [deadline] is
/// the time the caller has left: the whole call ends at the smaller of it and
/// the overall timeout of `LyricsHttp`.
class LyricsHttpRequest {
  const LyricsHttpRequest({
    required this.method,
    required this.uri,
    this.headers = const {},
    this.body,
    this.deadline,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final List<int>? body;
  final Duration? deadline;
}

/// The answer to a [LyricsHttpRequest], whatever its status: raw [bytes] (at
/// most 4 MiB, not decoded), response [headers] (lower-case names, repeated
/// ones joined with `, `), the request [url] (redirects are not followed)
/// and [sends], how many requests went out for this call, retries included.
class LyricsHttpRawResponse {
  const LyricsHttpRawResponse({
    required this.status,
    required this.bytes,
    required this.headers,
    required this.url,
    required this.sends,
  });

  final int status;
  final Uint8List bytes;
  final Map<String, String> headers;
  final Uri url;
  final int sends;
}

/// Thrown by `LyricsHttp.send` for a request that is malformed (a method
/// other than GET or POST, a bad header, a body over [lyricsMaxRequestBytes]
/// or on a GET). The fault is in the caller, not the network: nothing was
/// sent. [reason] names the problem and never holds a header value or body.
class LyricsRequestRejected implements Exception {
  const LyricsRequestRejected(this.reason);

  final String reason;

  @override
  String toString() => 'LyricsRequestRejected($reason)';
}

/// Headers the app sets itself or that would break the exchange; a source's
/// own are dropped without an error.
const _deniedHeaders = {
  'user-agent',
  'host',
  'connection',
  'content-length',
  'transfer-encoding',
  'te',
  'upgrade',
  'keep-alive',
  'trailer',
  'expect',
};

// RFC 9110 token.
final _tokenName = RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");

bool _validValue(String value) {
  for (final unit in value.codeUnits) {
    // ASCII only: no control characters (CR and LF included) except tab, and
    // no DEL. Dart refuses anything above DEL in a header value.
    if ((unit < 0x20 && unit != 0x09) || unit >= 0x7f) {
      return false;
    }
  }
  return true;
}

/// The headers to send for a source's [requested] ones: names lower-case,
/// the denied ones (`user-agent`, `host`, `proxy-*` and the like) dropped,
/// `accept` defaulting to `*/*`. Names that differ only in case keep the
/// last value. Throws [LyricsRequestRejected] for a name
/// that is not a token or a value with a control or non-ASCII character.
Map<String, String> lyricsRequestHeaders(Map<String, String> requested) {
  final result = <String, String>{};
  for (final entry in requested.entries) {
    final name = entry.key.toLowerCase();
    if (!_tokenName.hasMatch(name)) {
      throw const LyricsRequestRejected('header name');
    }
    if (!_validValue(entry.value)) {
      throw const LyricsRequestRejected('header value');
    }
    if (_deniedHeaders.contains(name) || name.startsWith('proxy-')) continue;
    result[name] = entry.value;
  }
  result.putIfAbsent('accept', () => '*/*');
  return result;
}

/// The method of [request] upper-cased (`GET`, `POST`, `get` or `post`
/// only), or throws [LyricsRequestRejected] for anything else, and for a body
/// that is too large, has a byte outside 0..255 or is sent with GET.
String checkLyricsRequest(LyricsHttpRequest request) {
  final method = switch (request.method) {
    'GET' || 'get' => 'GET',
    'POST' || 'post' => 'POST',
    _ => throw const LyricsRequestRejected('method'),
  };
  final body = request.body;
  if (body != null && method != 'POST') {
    throw const LyricsRequestRejected('body with GET');
  }
  if (body != null && body.length > lyricsMaxRequestBytes) {
    throw const LyricsRequestRejected('body too large');
  }
  if (body != null && body.any((byte) => byte < 0 || byte > 255)) {
    throw const LyricsRequestRejected('body');
  }
  return method;
}
