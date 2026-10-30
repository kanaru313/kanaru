import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/candidate_content_hash.dart';
import 'package:kanaru/core/lyrics/online/lyrics_candidate_checks.dart';
import 'package:kanaru/core/lyrics/online/lyrics_match.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';

import 'fake_lyrics_provider.dart';

const _query = LyricsQuery(
  title: 'Song',
  artist: 'Artist',
  duration: Duration(seconds: 200),
);

void main() {
  group('a result with no body at all', () {
    test('is judged on its metadata only', () {
      final good = matchCandidate(_query, fakeCandidate(body: null));
      expect(good.goodMatch, isTrue);
      expect(good.metadataGood, isTrue);

      final wrongArtist = matchCandidate(
        _query,
        fakeCandidate(artist: 'Other', body: null),
      );
      expect(wrongArtist.goodMatch, isFalse);
      expect(wrongArtist.metadataGood, isFalse);

      final farAway = matchCandidate(
        _query,
        fakeCandidate(duration: const Duration(seconds: 230), body: null),
      );
      expect(farAway.goodMatch, isFalse);
    });

    test('a body with nothing in it is still not a good match', () {
      final m = matchCandidate(_query, fakeCandidate(body: const LyricsBody()));
      expect(m.metadataGood, isTrue);
      expect(m.goodMatch, isFalse);
    });

    test('a rejected id never matches, even without a body', () {
      final c = fakeCandidate(body: null);
      final m = matchCandidate(_query, c, rejected: {c.ref});
      expect(m.rejected, isTrue);
      expect(m.goodMatch, isFalse);
    });

    test('has no content hash until its body is there', () {
      final c = fakeCandidate(body: null);
      expect(candidateContentHash(c), isNull);
      final fetched = c.withBody(const LyricsBody(plain: 'words'));
      expect(candidateContentHash(fetched), isNotNull);
    });

    test('the fetched text is checked against the rejected hashes', () {
      final c = fakeCandidate(body: null);
      final fetched = c.withBody(const LyricsBody(plain: 'words'));
      final hash = candidateContentHash(fetched)!;

      expect(
        matchCandidate(_query, c, rejectedHashes: {hash}).goodMatch,
        isTrue,
      );
      final judged = matchCandidate(_query, fetched, rejectedHashes: {hash});
      expect(judged.rejected, isTrue);
      expect(judged.goodMatch, isFalse);
    });
  });

  group('ranking', () {
    List<String> order(List<LyricsCandidate> list) => [
      for (final m in rankCandidates(_query, list)) m.candidate.remoteId,
    ];

    test('a body-less result ranks after one with a body', () {
      expect(
        order([
          fakeCandidate(remoteId: 'none', body: null),
          fakeCandidate(
            remoteId: 'plain',
            duration: const Duration(seconds: 202),
            body: const LyricsBody(plain: 'p'),
          ),
          fakeCandidate(remoteId: 'synced'),
          fakeCandidate(
            remoteId: 'inst',
            body: const LyricsBody(instrumental: true),
          ),
        ]),
        ['synced', 'plain', 'inst', 'none'],
      );
    });

    test('a good body-less result ranks before a result that is not good', () {
      expect(
        order([
          fakeCandidate(
            remoteId: 'far',
            duration: const Duration(seconds: 230),
          ),
          fakeCandidate(remoteId: 'none', body: null),
        ]),
        ['none', 'far'],
      );
    });

    test('body-less results keep delta, similarity and input order', () {
      expect(
        order([
          fakeCandidate(
            remoteId: 'late',
            duration: const Duration(seconds: 202),
            body: null,
          ),
          fakeCandidate(remoteId: 'exact', body: null),
          fakeCandidate(remoteId: 'tie', body: null),
        ]),
        ['exact', 'tie', 'late'],
      );
    });
  });
}
