import 'dart:async';
import 'dart:io';

import '../../lyrics_translation/translation_failure.dart';
import '../../lyrics_translation/translation_http.dart';
import 'lyrics_fetch_exception.dart';
import 'lyrics_http_request.dart';
import 'lyrics_http_retry.dart';

/// What [LyricsSendLoop.run] got: the last answer and how many requests went
/// out for it.
typedef LyricsSendResult = ({TranslationResponse response, int sends});

/// The send, retry and timeout rules shared by `LyricsHttp.get` and
/// `LyricsHttp.send`. The address and request checks are done by the caller.
class LyricsSendLoop {
  LyricsSendLoop({
    required this.client,
    required this.sleep,
    required this.abandoned,
    required this.allowed,
    required this.maxRetries,
  });

  final HttpClient client;
  final LyricsSleep sleep;
  final bool Function()? abandoned;
  final bool Function()? allowed;
  final int maxRetries;

  /// Sends the request and again after a short busy answer, within [timeout]
  /// for all sends and waits. Before every send `abandoned` is asked
  /// ([LyricsRequestAbandoned] if true) and then `allowed`
  /// (`notConsented` if false); nothing is sent in either case. Once the
  /// timeout hit or the lookup is abandoned, no further send goes out; nor
  /// after [maxSends] sends, when given.
  Future<LyricsSendResult> run({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required Duration timeout,
    List<int>? body,
    bool decode = true,
    void Function()? onSend,
    bool boundRequests = false,
    int? maxSends,
  }) async {
    final clock = Stopwatch()..start();
    var expired = false;
    var sends = 0;
    TranslationResponse? busy;
    Future<LyricsSendResult> loop() async {
      for (var retries = 0; ; retries++) {
        _checkAbandoned();
        checkAllowed();
        sends++;
        onSend?.call();
        // With [boundRequests] a socket never outlives the overall timeout.
        Duration? limit;
        if (boundRequests) {
          final left = timeout - clock.elapsed;
          limit = left < const Duration(milliseconds: 1)
              ? const Duration(milliseconds: 1)
              : left;
        }
        final response = await _send(method, uri, headers, body, decode, limit);
        if (response.status == 429 || response.status == 503) busy = response;
        // A send cap acts like running out of retries: the last answer stands.
        final capped = maxSends != null && sends >= maxSends;
        final wait = retries < maxRetries && !capped
            ? shortRetryWait(response.status, response.headers)
            : null;
        if (wait == null || expired) return (response: response, sends: sends);
        _checkAbandoned();
        await sleep(wait);
        if (expired) return (response: response, sends: sends);
      }
    }

    // Ends a call that ran out of time: `notConsented` when consent was
    // withdrawn meanwhile (no backoff), `rateLimited` with the last
    // `Retry-After` when a busy answer was seen, else `network`.
    Never expire() {
      expired = true;
      checkAllowed();
      final last = busy;
      if (last == null) {
        throw const LyricsFetchException(LyricsFetchKind.network);
      }
      throw LyricsFetchException(
        LyricsFetchKind.rateLimited,
        retryAfter: parseRetryAfter(last.headers['retry-after']),
      );
    }

    try {
      final result = await loop().timeout(timeout);
      // An answer that arrives after consent was withdrawn is dropped.
      checkAllowed();
      return result;
    } on LyricsFetchException catch (e) {
      if (boundRequests && e.kind == LyricsFetchKind.network) {
        // Any network failure of a bounded send re-checks consent. One that
        // came from the capped socket timer just before the overall timeout
        // is that timeout, and ends the same way.
        if (clock.elapsed >= timeout - const Duration(milliseconds: 50)) {
          expire();
        }
        checkAllowed();
      }
      rethrow;
    } on TimeoutException {
      expire();
    }
  }

  /// Throws [LyricsRequestAbandoned] when the lookup was abandoned.
  void checkAbandoned() => _checkAbandoned();

  void _checkAbandoned() {
    if (abandoned?.call() ?? false) throw const LyricsRequestAbandoned();
  }

  void checkAllowed() {
    if (!(allowed?.call() ?? true)) {
      throw const LyricsFetchException(LyricsFetchKind.notConsented);
    }
  }

  Future<TranslationResponse> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    List<int>? body,
    bool decode,
    Duration? limit,
  ) async {
    try {
      return await sendTranslationRequest(
        client,
        connectTimeout: _shorter(translationConnectTimeout, limit),
        requestTimeout: _shorter(translationRequestTimeout, limit),
        method: method,
        uri: uri,
        headers: headers,
        bodyBytes: body,
        decode: decode,
        maxBytes: lyricsMaxResponseBytes,
      );
    } on TranslationException catch (e) {
      throw LyricsFetchException(
        e.kind == TranslationFailureKind.network
            ? LyricsFetchKind.network
            : LyricsFetchKind.invalidResponse,
      );
    }
  }
}

Duration _shorter(Duration normal, Duration? limit) =>
    limit != null && limit < normal ? limit : normal;
