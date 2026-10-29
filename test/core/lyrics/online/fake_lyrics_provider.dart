import 'dart:async';

import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';

/// A [LyricsCandidate] that passes the match gate for [fakeQuery]-like
/// songs unless a field is changed.
LyricsCandidate fakeCandidate({
  String providerId = 'fake',
  String remoteId = '1',
  String title = 'Song',
  String artist = 'Artist',
  Duration? duration = const Duration(seconds: 200),
  LyricsBody? body = const LyricsBody(syncedLrc: '[00:01.00] hello'),
}) => LyricsCandidate(
  providerId: providerId,
  remoteId: remoteId,
  title: title,
  artist: artist,
  duration: duration,
  body: body,
);

/// A scripted provider. [lookupResult] is a `LyricsCandidate?` or an error
/// to throw, [searchResult] a `List<LyricsCandidate>` or an error. When
/// [gate] is set, a lookup waits for it before answering, so a test can
/// hold a request in flight.
///
/// It keeps the contract of a real provider: a lookup without a title or a
/// primary artist throws [ArgumentError], and every call is counted together
/// with the [LyricsHttp] it was given (the one the host's consent check
/// handed out).
class FakeLyricsProvider implements LyricsProvider {
  FakeLyricsProvider({this.id = 'fake'});

  @override
  final String id;

  @override
  String get displayName => 'Fake';

  @override
  List<String> get hosts => const ['fake.example'];

  Object? lookupResult;
  Object? searchResult = const <LyricsCandidate>[];
  Completer<void>? gate;

  int lookupCalls = 0;
  int searchCalls = 0;
  final queries = <LyricsQuery>[];
  final received = <LyricsHttp>[];

  @override
  Future<LyricsCandidate?> lookup(LyricsQuery query, LyricsHttp http) async {
    lookupCalls++;
    queries.add(query);
    received.add(http);
    if ((query.title?.trim() ?? '').isEmpty ||
        (query.artist?.trim() ?? '').isEmpty) {
      throw ArgumentError('lookup needs a title and a primary artist');
    }
    await gate?.future;
    final result = lookupResult;
    if (result is Exception || result is Error) throw result!;
    return result as LyricsCandidate?;
  }

  @override
  Future<List<LyricsCandidate>> search(
    LyricsQuery query,
    LyricsHttp http,
  ) async {
    searchCalls++;
    received.add(http);
    final result = searchResult;
    if (result is Exception || result is Error) throw result!;
    return result! as List<LyricsCandidate>;
  }

  @override
  Future<LyricsBody?> fetch(String remoteId, LyricsHttp http) async => null;
}
