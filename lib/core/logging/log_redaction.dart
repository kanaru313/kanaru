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
  var end = text.length;
  if (end > maxRecordChars) {
    end = maxRecordChars;
    // Do not cut a surrogate pair in half.
    if (_isHighSurrogate(text.codeUnitAt(end - 1))) end--;
  }
  final out = _postMask(_pipeline(text.substring(0, end)));
  if (end == text.length) return out;
  // The marker is appended last: it is not part of a secret.
  return '${_maskLastWord(out)}…[truncated ${text.length - end} chars]';
}

/// The rules, then the percent-decoded copy when it holds more to mask.
String _pipeline(String text) {
  final out = _redactPlain(text);
  if (!out.contains('%')) return out;
  final decoded = _percentDecode(out);
  final redacted = _redactPlain(decoded);
  return redacted == decoded ? out : redacted;
}

/// Masking applied to the finished output, plain and percent-decoded. It runs
/// after every other rule so it can only remove text: run before them, it
/// would swallow the name of a secret (`&p=hunt@x`) and leave the value
/// behind for no rule to find.
String _postMask(String out) {
  if (out.contains('@')) {
    out = out.replaceAllMapped(_longUserInfo, _maskLongUserInfo);
  }
  if (!out.contains('%')) return out;
  final decoded = _percentDecode(out);
  if (!decoded.contains('@')) return out;
  final masked = decoded.replaceAllMapped(_longUserInfo, _maskLongUserInfo);
  return masked == decoded ? out : masked;
}

/// A secret cut in half by the cap (`https://u:secr`) has no `@` or
/// separator left for the rules to find. Runs on the redacted result: the
/// last word is masked from its first `:`, `=`, `@` or `%` on, which keeps
/// whatever the rules would have masked in the uncut word. Prefers masking
/// too much (a cut `file.dart:12` becomes `file.dart:***`).
String _maskLastWord(String cut) {
  var start = cut.length;
  while (start > 0 && !_isSpace(cut.codeUnitAt(start - 1))) {
    start--;
  }
  for (var i = start; i < cut.length; i++) {
    if (_isCutMarker(cut.codeUnitAt(i))) return '${cut.substring(0, i + 1)}***';
  }
  return cut;
}

bool _isCutMarker(int unit) =>
    unit == 0x3a || unit == 0x3d || unit == 0x40 || unit == 0x25; // : = @ %

/// Ends a word in a log line: ASCII whitespace and no-break space. Unicode
/// spaces that `\s` also matches are not included, so a word may be taken as
/// longer than the patterns see it, which only masks more.
bool _isSpace(int unit) =>
    unit == 0x20 || (unit >= 0x09 && unit <= 0x0d) || unit == 0xa0;

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

/// One redaction pass. Each rule runs only when the text holds a literal that
/// every match of that rule contains, so a long line that cannot match skips
/// the regex scan. The triggers are checked on the text this pass receives:
/// the decoded copy has its own `@`, `authorization`, and so on. Masking only
/// removes text, so a trigger absent from the input cannot appear mid-pass.
String _redactPlain(String text) {
  final lower = text.toLowerCase(); // Once per pass, for the name triggers.
  var out = text;
  if (text.contains('@')) {
    // Trigger '@': both user info forms end in it.
    out = out.replaceAll(_userInfo, '://***@');
    // Trigger ':' as well: `user:pass@`.
    if (text.contains(':')) out = out.replaceAll(_bareUserInfo, '***@');
  }
  if (lower.contains('authorization')) {
    // Trigger 'authorization': the header name is part of the match.
    out = out.replaceAllMapped(_authorization, (m) {
      final scheme = m[3];
      return '${m[1]}${m[2]}${scheme == null ? '' : '$scheme '}***';
    });
  }
  // Trigger 'cookie': `cookie`, `cookies` and `set-cookie` all hold it.
  if (lower.contains('cookie')) {
    out = out.replaceAllMapped(_cookie, (m) => '${m[1]}${m[2]}***');
  }
  // Trigger 'bearer': the word is part of the match.
  if (lower.contains('bearer')) {
    out = out.replaceAllMapped(_bearer, (m) => '${m[1]}${m[2]}***');
  }
  // Trigger 'eyJ': a JWT header, base64 of `{"`; the rule is case sensitive.
  if (text.contains('eyJ')) out = out.replaceAll(_jwt, '***');
  // Trigger ':' or '=': a pair needs its separator.
  if (text.contains(':') || text.contains('=')) return _maskPairs(out);
  return out;
}

/// `scheme://user:pass@host`: everything between `://` and the last `@` of
/// the word, since a password may hold `/`, `#` or `@`. `file:///` has no
/// user info.
///
/// The patterns below that scan names start only where a run of name
/// characters starts (the lookbehind). Otherwise every position of a long
/// run would be tried, and the time would grow with the square of its length.
final _userInfo = RegExp(r'://(?!/)\S{0,128}@');

/// A word whose user info is longer than the bound of [_userInfo]: from the
/// first `://` that has more than 128 characters after it to the end of the
/// word. Matches do not overlap, so a word is scanned once. Used by
/// [_postMask] only.
final _longUserInfo = RegExp(r'://(?!/)\S{129,}');

/// Masks up to the last `@` of the word, as [_userInfo] does. A word with no
/// `@` is not user info and stays.
String _maskLongUserInfo(Match m) {
  final word = m[0]!;
  final at = word.lastIndexOf('@');
  return at < 0 ? word : '://***${word.substring(at)}';
}

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

/// Cheap test that a text holds anything [_pair] could hand to
/// [_isSecretName]: a secret word, `x-amz-`, or a short exact name followed
/// by its separator. Every name [_isSecretName] accepts contains one of
/// them, so a line without a hit skips the pair scan. Plain `contains` on a
/// lowercased copy: a case-insensitive regex alternation is several times
/// slower on long text.
bool _mayHoldSecretPair(String text) {
  final lower = text.toLowerCase();
  for (final word in _hintWords) {
    if (lower.contains(word)) return true;
  }
  return _shortNamePair.hasMatch(text);
}

const _hintWords = [
  'token', 'secret', 'pass', 'pwd', 'key', 'sig', 'auth', 'session', //
  'sessid', 'code', 'jwt', 'credential', 'ticket', 'otp', 'x-amz-',
];

final _shortNamePair = RegExp(
  r'''(?<![\w.\-])(?:p|t|s|pw|sid)["']?\s{0,3}[:=]''',
  caseSensitive: false,
);

String _maskPairs(String text) {
  if (!_mayHoldSecretPair(text)) return text;
  final out = StringBuffer();
  var copied = 0;
  for (final pair in _pair.allMatches(text)) {
    if (pair.start < copied) continue; // Inside a value already masked.
    final inQuery = pair[1] != null;
    if (!_isSecretName(pair[2]!, inQuery)) continue;
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

/// Secret names, matched against a name taken from [_pair] (ASCII only).
/// One alternation per place, instead of a list of `contains` calls per pair.
///
/// Words that mark a URL parameter as secret when they appear anywhere in its
/// name, Subsonic's password, token and salt parameters (`p`, `t`, `s`, `pw`,
/// `sid`) and S3 presigned parameters.
final _queryName = RegExp(
  r'^(?:p|t|s|pw|sid)$|^x-amz-|token|secret|pass|pwd|key|sig|auth|session|'
  r'sessid|code|jwt|credential|ticket|otp',
  caseSensitive: false,
);

/// Narrower list for pairs found in prose, where `code: 404` and
/// `signal: SIGTERM` are common.
final _proseName = RegExp(
  r'^(?:pw|pass|otp|sid|ticket|key|auth)$|token|secret|passw|pwd|apikey|'
  r'api_key|api-key|accesskey|access_key|private_key|credential|jwt|'
  r'sessionid|session_id|sessid|signature',
  caseSensitive: false,
);

/// X-Api-Key, X-Plex-Token, X-MediaBrowser-Token and the like.
final _headerName = RegExp(r'^x-.*(?:token|key|auth)', caseSensitive: false);

bool _isSecretName(String name, bool inQuery) =>
    _headerName.hasMatch(name) ||
    (inQuery ? _queryName : _proseName).hasMatch(name);
