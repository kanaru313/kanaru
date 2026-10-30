import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'translation_failure.dart';

/// Largest response body read, in bytes. A translation answer is a few KiB;
/// anything bigger is not one.
const maxTranslationResponseBytes = 2 * 1024 * 1024;

/// How long opening the connection may take.
const translationConnectTimeout = Duration(seconds: 10);

/// How long the whole request, response body included, may take.
const translationRequestTimeout = Duration(seconds: 20);

/// What came back from a service: the HTTP [status], the decoded [body], the
/// response [headers] (lower-case names) and the raw [bytes]. [bytes] is
/// filled only when the request asked for `decode: false`; [body] is then
/// empty. Otherwise [bytes] is empty.
typedef TranslationResponse = ({
  int status,
  String body,
  Map<String, String> headers,
  Uint8List bytes,
});

/// Sends one request and reads the whole answer, whatever the status. Every
/// failure leaves as a [TranslationException]:
///
/// * no connection, TLS failure, broken stream or timeout: `network`;
/// * body over [maxBytes] (default [maxTranslationResponseBytes]), or a 2xx
///   body that is not UTF-8: `invalidResponse` (an error status keeps its
///   meaning, so its body is decoded leniently);
/// * a header value Dart refuses (it quotes the value in its message):
///   `badKey`, since only the API key is ever sent as a custom header;
/// * any other [Exception]: `invalidResponse`. Errors are not caught.
///
/// Redirects are not followed: a 3xx comes back as the response.
///
/// [bodyBytes], when given, is sent as the request body instead of [body]
/// (the two are exclusive). With `decode: false` the answer is not read as
/// text: its raw bytes are in [TranslationResponse.bytes] and no UTF-8 check
/// is made. The caller then owns header validation: a refused header value
/// still maps to `badKey`.
///
/// The original exception is never attached or logged: its text may hold
/// header values or the request address. No retry is made here.
Future<TranslationResponse> sendTranslationRequest(
  HttpClient client, {
  required String method,
  required Uri uri,
  Map<String, String> headers = const {},
  String? body,
  List<int>? bodyBytes,
  bool decode = true,
  Duration connectTimeout = translationConnectTimeout,
  Duration requestTimeout = translationRequestTimeout,
  int maxBytes = maxTranslationResponseBytes,
}) async {
  assert(body == null || bodyBytes == null, 'body and bodyBytes are exclusive');
  // Kept so that a request still connecting when we give up is aborted
  // once it opens, instead of leaking.
  final Future<HttpClientRequest> pending;
  try {
    pending = client.openUrl(method, uri);
  } on StateError {
    // A closed client throws at once.
    throw const TranslationException(TranslationFailureKind.network);
  }
  try {
    return await _exchange(
      pending,
      headers,
      bodyBytes ?? (body == null ? null : utf8.encode(body)),
      decode,
      connectTimeout,
      requestTimeout,
      maxBytes,
    ).timeout(requestTimeout);
  } on TranslationException {
    _abortWhenOpen(pending);
    rethrow;
  } on FormatException {
    // The 2xx body was not UTF-8.
    _abortWhenOpen(pending);
    throw const TranslationException(TranslationFailureKind.invalidResponse);
  } on SocketException {
    throw const TranslationException(TranslationFailureKind.network);
  } on HandshakeException {
    throw const TranslationException(TranslationFailureKind.network);
  } on TlsException {
    throw const TranslationException(TranslationFailureKind.network);
  } on HttpException {
    throw const TranslationException(TranslationFailureKind.network);
  } on TimeoutException {
    _abortWhenOpen(pending);
    throw const TranslationException(TranslationFailureKind.network);
  } on Exception {
    _abortWhenOpen(pending);
    throw const TranslationException(TranslationFailureKind.invalidResponse);
  }
}

void _abortWhenOpen(Future<HttpClientRequest> pending) {
  unawaited(pending.then((request) => request.abort(), onError: (_) {}));
}

Future<TranslationResponse> _exchange(
  Future<HttpClientRequest> pending,
  Map<String, String> headers,
  List<int>? body,
  bool decode,
  Duration connectTimeout,
  Duration requestTimeout,
  int maxBytes,
) async {
  final clock = Stopwatch()..start();
  final HttpClientRequest request;
  try {
    request = await pending.timeout(connectTimeout);
  } on StateError {
    throw const TranslationException(TranslationFailureKind.network);
  }
  request.followRedirects = false;
  try {
    headers.forEach((name, value) => request.headers.set(name, value));
  } on FormatException {
    // The message of the original quotes the value, so it is dropped.
    throw const TranslationException(TranslationFailureKind.badKey);
  }
  if (body != null) {
    request.contentLength = body.length;
    request.add(body);
  }
  final response = await request.close();
  final chunks = BytesBuilder(copy: false);
  // Leaving this loop cancels the response subscription, which closes the
  // connection; abort() cannot do that once the headers have arrived. The
  // stream times out when no data comes for the time left.
  final left = requestTimeout - clock.elapsed;
  await for (final chunk in response.timeout(
    left.isNegative ? Duration.zero : left,
  )) {
    chunks.add(chunk);
    if (clock.elapsed > requestTimeout) throw TimeoutException(null);
    if (chunks.length > maxBytes) {
      throw const TranslationException(TranslationFailureKind.invalidResponse);
    }
  }
  final received = <String, String>{};
  response.headers.forEach(
    (name, values) => received[name] = values.join(', '),
  );
  final status = response.statusCode;
  if (!decode) {
    return (
      status: status,
      body: '',
      headers: received,
      bytes: chunks.takeBytes(),
    );
  }
  return (
    status: status,
    // An error status keeps its meaning even when its body is garbage.
    body: utf8.decode(
      chunks.takeBytes(),
      allowMalformed: status < 200 || status >= 300,
    ),
    headers: received,
    bytes: Uint8List(0),
  );
}
