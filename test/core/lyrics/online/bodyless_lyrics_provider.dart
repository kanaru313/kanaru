import 'dart:async';

import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http_retry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';

import 'fake_lyrics_provider.dart';

/// A two-step source: its search answers come without lyrics (build them
/// with `fakeCandidate(body: null)`) and `fetch` gives them out by
/// `remoteId`.
///
/// [bodies] maps a `remoteId` to a `LyricsBody?` or an error to throw; an id
/// that is not there answers `null`. A fetch waits for [fetchGate] when it
/// is set. Every search waits for a completer of [searchGates] a test
/// completes, and when [sendAfterGate] is set it then sends one request
/// through the [LyricsHttp] it was given, so a test can see that a replaced
/// search sends nothing.
class BodylessLyricsProvider extends FakeLyricsProvider {
  BodylessLyricsProvider({super.id});

  final bodies = <String, Object?>{};
  final fetched = <String>[];
  Completer<void>? fetchGate;

  final searchGates = <Completer<void>>[];
  bool holdSearches = false;
  bool sendAfterGate = false;

  /// Searches whose request was refused because they were abandoned.
  int abandonedSends = 0;

  @override
  Future<List<LyricsCandidate>> search(
    LyricsQuery query,
    LyricsHttp http,
  ) async {
    final probe = sendAfterGate;
    if (holdSearches) {
      final gate = Completer<void>();
      searchGates.add(gate);
      await gate.future;
    }
    if (probe) {
      try {
        await http.get(Uri.https(hosts.first, '/search'));
      } on LyricsRequestAbandoned {
        abandonedSends++;
        rethrow;
      }
    }
    return super.search(query, http);
  }

  @override
  Future<LyricsBody?> fetch(String remoteId, LyricsHttp http) async {
    fetched.add(remoteId);
    received.add(http);
    await fetchGate?.future;
    final result = bodies[remoteId];
    if (result is Exception || result is Error) throw result!;
    return result as LyricsBody?;
  }
}
