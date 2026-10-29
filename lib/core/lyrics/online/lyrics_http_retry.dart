import 'lyrics_fetch_exception.dart';

/// How often a request is sent again after a short "busy" answer.
const maxShortRetries = 2;

/// Longest `Retry-After` that is waited out inside the request. Anything
/// longer is left to the caller's backoff.
const maxShortRetryWait = Duration(seconds: 5);

/// Longest one `LyricsHttp.get` may take in all, sends and waits together.
const lyricsOverallTimeout = Duration(seconds: 30);

/// Waits [wait]; tests replace it with an instant one.
typedef LyricsSleep = Future<void> Function(Duration wait);

Future<void> realLyricsSleep(Duration wait) => Future<void>.delayed(wait);

/// Thrown instead of a second send when the lookup was abandoned (song
/// changed, Now Playing closed) during the wait. Not a request failure: it
/// is never logged or fed to the backoff.
class LyricsRequestAbandoned implements Exception {
  const LyricsRequestAbandoned();

  @override
  String toString() => 'LyricsRequestAbandoned';
}

/// How long to wait before sending again after [status] with [headers]
/// (lower-case names), or `null` when the answer is final. Only 429 and 503
/// qualify, and only with a `Retry-After` of at most [maxShortRetryWait]; a
/// 503 without the header counts as [minRetryAfter], a 429 without it as
/// final.
Duration? shortRetryWait(int status, Map<String, String> headers) {
  if (status != 429 && status != 503) return null;
  final wait =
      parseRetryAfter(headers['retry-after']) ??
      (status == 503 ? minRetryAfter : null);
  return wait != null && wait <= maxShortRetryWait ? wait : null;
}
