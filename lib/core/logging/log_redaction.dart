/// Longest record kept, in UTF-16 units. Redaction time grows with the text,
/// and one log line must not be able to freeze the UI isolate or fill the
/// file.
const maxRecordChars = 16 * 1024;

/// Safety net for PRIV-04: masks credentials that slipped into a log line.
///
/// Runs on the whole formatted record, error and stack trace included.
/// Callers must still keep secrets out of log messages; this only catches
/// what they missed. Matching ignores case and prefers masking too much
/// (`?t=30` is masked as well) over masking too little.
///
/// Every pattern is bounded, so the time is linear in the (capped) length.
/// A secret that only shows up percent-encoded (a proxied URL in `?url=`) is
/// found in a decoded copy; the record is then logged decoded.
String redactSecrets(String text) {
  final out = _redactPlain(_cap(text));
  if (!out.contains('%')) return out;
  final decoded = _percentDecode(out);
  final redacted = _redactPlain(decoded);
  return redacted == decoded ? out : redacted;
}

String _cap(String text) {
  if (text.length <= maxRecordChars) return text;
  var end = maxRecordChars;
  // Do not cut a surrogate pair in half.
  if (_isHighSurrogate(text.codeUnitAt(end - 1))) end--;
  return '${text.substring(0, end)}…[truncated ${text.length - end} chars]';
}

bool _isHighSurrogate(int unit) => unit >= 0xd800 && unit <= 0xdbff;

String _percentDecode(String text) {
  try {
    return Uri.decodeComponent(text);
  } catch (_) {
    // Malformed escapes or invalid UTF-8: decode what is plain ASCII.
    return text.replaceAllMapped(
      RegExp(r'%([0-7][0-9a-f])', caseSensitive: false),
      (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)),
    );
  }
}

String _redactPlain(String text) {
  var out = text.replaceAll(_userInfo, '://***@');
  out = out.replaceAll(_bareUserInfo, '***@');
  out = out.replaceAllMapped(_authorization, (m) {
    final scheme = m[3];
    return '${m[1]}${m[2]}${scheme == null ? '' : '$scheme '}***';
  });
  out = out.replaceAllMapped(_cookie, (m) => '${m[1]}${m[2]}***');
  out = out.replaceAllMapped(_bearer, (m) => '${m[1]}${m[2]}***');
  out = out.replaceAll(_jwt, '***');
  return _maskPairs(out);
}

/// `scheme://user:pass@host`: everything between `://` and the last `@` of
/// the word, since a password may hold `/`, `#` or `@`. `file:///` has no
/// user info.
///
/// The patterns below that scan names start only where a run of name
/// characters starts (the lookbehind). Otherwise every position of a long
/// run would be tried, and the time would grow with the square of its length.
final _userInfo = RegExp(r'://(?!/)\S{0,128}@');

/// `user:pass@host` without a scheme.
final _bareUserInfo = RegExp(r'(?<![\w.\-])[\w.\-]{1,64}:[^\s@/:]{1,128}@');

/// `Authorization: Bearer x`, `Proxy-Authorization: Basic x`,
/// `authorization=x`: masked to the end of the line, since schemes such as
/// Digest or MediaBrowser carry several `key="value"` pairs.
final _authorization = RegExp(
  r'\b((?:proxy-)?authorization)(\s{0,3}[:=]\s{0,3})'
  r'(?:(bearer|basic|digest|token)\s+)?[^\r\n]+',
  caseSensitive: false,
);

/// `Cookie:`, `Cookies:` and `Set-Cookie:` headers, to the end of the line.
final _cookie = RegExp(
  r'\b(cookies?)(\s{0,3}[:=]\s{0,3})[^\r\n]+',
  caseSensitive: false,
);

/// A bare `Bearer x`, such as a header printed as a map.
final _bearer = RegExp(r'\b(bearer)(\s{1,3})[^\s,;]+', caseSensitive: false);

/// A JSON web token on its own.
final _jwt = RegExp(r'\beyJ[\w\-]{5,512}\.[\w\-]{1,512}\.[\w\-]{1,512}');

/// A `name=value` or `name: value` pair, seen from the name up to the
/// value. [_maskPairs] decides from the name whether to mask, then finds
/// the end of the value; the value is not part of the match, so a secret
/// inside the value of another parameter (`?url=https://h/?t=x`) is found.
/// Group 1 is the separator that opens a URL parameter, group 2 the name.
final _pair = RegExp(
  r'''([?&#;])?(?<![\w.\-])([\w.\-]{1,128})["']?\s{0,3}[:=]\s{0,3}''',
);

/// Value of a URL parameter: up to the next separator or space.
final _queryValue = RegExp(r'[^&#;\s]*');

/// Value of a pair in prose, JSON or a Dart map; quoted values may hold
/// anything.
final _looseValue = RegExp(r'''"[^"\r\n]*"?|'[^'\r\n]*'?|[^\s&#;,}\])"']*''');

String _maskPairs(String text) {
  final out = StringBuffer();
  var copied = 0;
  for (final pair in _pair.allMatches(text)) {
    if (pair.start < copied) continue; // Inside a value already masked.
    final inQuery = pair[1] != null;
    if (!_isSecretName(pair[2]!.toLowerCase(), inQuery)) continue;
    final value = (inQuery ? _queryValue : _looseValue).matchAsPrefix(
      text,
      pair.end,
    )!;
    final raw = value[0]!;
    final quote = raw.isNotEmpty && (raw[0] == '"' || raw[0] == "'")
        ? raw[0]
        : '';
    out
      ..write(text.substring(copied, pair.end))
      ..write('$quote***$quote');
    copied = value.end;
  }
  if (copied == 0) return text;
  return (out..write(text.substring(copied))).toString();
}

/// Words that mark a URL parameter as secret when they appear anywhere in
/// its name.
const _queryWords = [
  'token', 'secret', 'pass', 'pwd', 'key', 'sig', 'auth', 'session', //
  'sessid', 'code', 'jwt', 'credential', 'ticket', 'otp',
];

/// Subsonic's password, token and salt parameters.
const _queryNames = {'p', 't', 's', 'pw', 'sid'};

/// Narrower list for pairs found in prose, where `code: 404` and
/// `signal: SIGTERM` are common.
const _proseWords = [
  'token', 'secret', 'passw', 'pwd', 'apikey', 'api_key', 'api-key', //
  'accesskey', 'access_key', 'private_key', 'credential', 'jwt', //
  'sessionid', 'session_id', 'sessid', 'signature',
];

const _proseNames = {'pw', 'pass', 'otp', 'sid', 'ticket', 'key', 'auth'};

bool _isSecretName(String name, bool inQuery) {
  // S3 presigned URLs.
  if (inQuery && name.startsWith('x-amz-')) return true;
  // X-Api-Key, X-Plex-Token, X-MediaBrowser-Token and the like.
  if (name.startsWith('x-') &&
      (name.contains('token') ||
          name.contains('key') ||
          name.contains('auth'))) {
    return true;
  }
  if (inQuery) {
    return _queryNames.contains(name) || _queryWords.any(name.contains);
  }
  return _proseNames.contains(name) || _proseWords.any(name.contains);
}
