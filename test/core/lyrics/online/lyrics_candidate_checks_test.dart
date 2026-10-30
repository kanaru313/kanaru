import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_candidate_checks.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';

import 'fake_lyrics_provider.dart';

LyricsCandidate? _check(LyricsCandidate c) =>
    checkCandidate(c, providerId: 'fake');

void main() {
  group('remoteId', () {
    test('empty, blank, over 256 or with a control character is invalid', () {
      expect(_check(fakeCandidate(remoteId: '')), isNull);
      expect(_check(fakeCandidate(remoteId: '   ')), isNull);
      expect(_check(fakeCandidate(remoteId: 'a' * 257)), isNull);
      expect(_check(fakeCandidate(remoteId: 'a\nb')), isNull);
      expect(_check(fakeCandidate(remoteId: 'a\u0000b')), isNull);
      expect(_check(fakeCandidate(remoteId: 'a\u007Fb')), isNull);
    });

    test('256 characters are fine', () {
      expect(_check(fakeCandidate(remoteId: 'a' * 256)), isNotNull);
    });
  });

  group('title, artist and album', () {
    test('title and artist must be non-empty after trimming', () {
      expect(_check(fakeCandidate(title: '  \t')), isNull);
      expect(_check(fakeCandidate(artist: '')), isNull);
      expect(_check(fakeCandidate(title: '\u0007')), isNull);
    });

    test('over 512 characters is invalid, 512 is fine', () {
      expect(_check(fakeCandidate(title: 'a' * 513)), isNull);
      expect(_check(fakeCandidate(artist: 'a' * 513)), isNull);
      expect(_check(fakeCandidate(title: 'a' * 512)), isNotNull);
    });

    test('an over-long album is dropped, not the candidate', () {
      final c = LyricsCandidate(
        providerId: 'fake',
        remoteId: '1',
        title: 'T',
        artist: 'A',
        album: 'a' * 513,
      );
      final checked = _check(c)!;
      expect(checked.album, isNull);
      expect(checked.title, 'T');
    });

    test('a kept album and clean labels stay', () {
      final checked = _check(
        const LyricsCandidate(
          providerId: 'fake',
          remoteId: '1',
          title: ' Ti\u0007tle ',
          artist: 'A',
          album: 'Alb',
        ),
      )!;
      expect(checked.title, 'Title');
      expect(checked.album, 'Alb');
    });
  });

  group('duration', () {
    test('zero, negative and 24 h or more are dropped, not the candidate', () {
      for (final d in [
        Duration.zero,
        const Duration(seconds: -5),
        const Duration(hours: 24),
        const Duration(days: 3),
      ]) {
        final checked = _check(fakeCandidate(duration: d))!;
        expect(checked.duration, isNull, reason: '$d');
      }
    });

    test('a normal duration stays', () {
      final checked = _check(
        fakeCandidate(duration: const Duration(hours: 23, minutes: 59)),
      )!;
      expect(checked.duration, const Duration(hours: 23, minutes: 59));
    });
  });

  group('body', () {
    test('control characters go, newline and tab stay, CRLF becomes LF', () {
      final body = checkBody(
        const LyricsBody(plain: 'a\r\nb\tc\u0007d\x1B\re\u007F'),
      )!;
      expect(body.plain, 'a\nb\tcde');
    });

    test('a text over 1 MiB is dropped, exactly 1 MiB stays', () {
      final big = 'a' * (maxLyricsTextBytes + 1);
      final fits = 'a' * maxLyricsTextBytes;
      expect(checkBody(LyricsBody(plain: big))!.plain, isNull);
      expect(checkBody(LyricsBody(plain: fits))!.plain, fits);
    });

    test('the limit counts UTF-8 bytes, not characters', () {
      // Two bytes each: half a million fits, a bit more does not.
      expect(checkBody(LyricsBody(plain: 'é' * 524288))!.plain, isNotNull);
      expect(checkBody(LyricsBody(plain: 'é' * 524289))!.plain, isNull);
    });

    test('synced text that does not parse moves to plain', () {
      final body = checkBody(const LyricsBody(syncedLrc: 'just some words'))!;
      expect(body.syncedLrc, isNull);
      expect(body.plain, 'just some words');
    });

    test('unparsed synced text does not replace an existing plain text', () {
      final body = checkBody(
        const LyricsBody(syncedLrc: 'words', plain: 'real plain'),
      )!;
      expect(body.syncedLrc, isNull);
      expect(body.plain, 'real plain');
    });

    test('synced text that parses stays synced', () {
      const text = '[00:01.00] a\n[00:02.00] b';
      expect(checkBody(const LyricsBody(syncedLrc: text))!.syncedLrc, text);
    });

    test('a blank text becomes null and the flag stays', () {
      final body = checkBody(
        const LyricsBody(plain: ' \n ', instrumental: true),
      )!;
      expect(body.plain, isNull);
      expect(body.instrumental, isTrue);
    });

    test('a fetched body with nothing usable is null', () {
      expect(checkFetchedBody(null), isNull);
      expect(checkFetchedBody(const LyricsBody(plain: '  ')), isNull);
      expect(
        checkFetchedBody(const LyricsBody(instrumental: true))!.instrumental,
        isTrue,
      );
    });
  });

  group('lists', () {
    test('the provider id is forced to the registration id', () {
      final list = checkCandidates([
        fakeCandidate(providerId: 'liar'),
      ], providerId: 'fake');
      expect(list.single.providerId, 'fake');
    });

    test('a duplicate remoteId is dropped, the first wins', () {
      final list = checkCandidates([
        fakeCandidate(remoteId: 'x', title: 'First'),
        fakeCandidate(remoteId: 'x', title: 'Second'),
        fakeCandidate(remoteId: 'y'),
      ], providerId: 'fake');
      expect(list.map((c) => c.title), ['First', 'Song']);
    });

    test('21 results become 20', () {
      final list = checkCandidates([
        for (var i = 0; i < 21; i++) fakeCandidate(remoteId: '$i'),
      ], providerId: 'fake');
      expect(list, hasLength(20));
      expect(list.last.remoteId, '19');
    });

    test('invalid candidates are dropped, the rest stays', () {
      final list = checkCandidates([
        fakeCandidate(remoteId: ''),
        fakeCandidate(remoteId: 'ok'),
        fakeCandidate(remoteId: 'bad', title: ''),
      ], providerId: 'fake');
      expect(list.map((c) => c.remoteId), ['ok']);
    });

    test('an empty list is an empty list', () {
      expect(checkCandidates(const [], providerId: 'fake'), isEmpty);
    });

    test('a non-empty list of nothing valid is an invalid response', () {
      expect(
        () => checkCandidates([
          fakeCandidate(remoteId: ''),
          fakeCandidate(title: ' '),
        ], providerId: 'fake'),
        throwsA(
          isA<LyricsFetchException>().having(
            (e) => e.kind,
            'kind',
            LyricsFetchKind.invalidResponse,
          ),
        ),
      );
    });

    test('lookup: null stays null, an invalid record throws', () {
      expect(checkLookupCandidate(null, providerId: 'fake'), isNull);
      expect(
        () => checkLookupCandidate(
          fakeCandidate(remoteId: ''),
          providerId: 'fake',
        ),
        throwsA(isA<LyricsFetchException>()),
      );
    });
  });

  group('hasBody and withBody', () {
    test('only words or the instrumental flag count', () {
      expect(fakeCandidate(body: null).hasBody, isFalse);
      expect(fakeCandidate(body: const LyricsBody()).hasBody, isFalse);
      expect(fakeCandidate().hasBody, isTrue);
      expect(
        fakeCandidate(body: const LyricsBody(instrumental: true)).hasBody,
        isTrue,
      );
    });

    test('withBody keeps the rest of the record', () {
      final c = fakeCandidate(remoteId: 'k', body: null);
      final withBody = c.withBody(const LyricsBody(plain: 'p'));
      expect((withBody.remoteId, withBody.title), ('k', 'Song'));
      expect(withBody.body!.plain, 'p');
    });
  });
}
