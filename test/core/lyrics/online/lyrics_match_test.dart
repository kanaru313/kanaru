import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/text_keys.dart';
import 'package:kanaru/core/lyrics/online/candidate_content_hash.dart';
import 'package:kanaru/core/lyrics/online/lyrics_match.dart';
import 'package:kanaru/core/lyrics/online/lyrics_match_keys.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';

const _body = LyricsBody(syncedLrc: '[00:01.00] a', plain: 'a');

LyricsCandidate _candidate(
  String title,
  String artist, {
  int id = 1,
  Duration? duration = const Duration(seconds: 200),
  LyricsBody? body = _body,
}) => LyricsCandidate(
  providerId: 'lrclib',
  remoteId: '$id',
  title: title,
  artist: artist,
  duration: duration,
  body: body,
);

/// Whether a candidate passes the gate for a song of 200 s.
bool _good(
  String title,
  String? artist,
  String candidateTitle,
  String candidateArtist, {
  double delta = 0,
  LyricsBody? body = _body,
}) {
  final query = LyricsQuery(
    title: title,
    artist: artist,
    duration: const Duration(seconds: 200),
  );
  final duration = Duration(milliseconds: 200000 + (delta * 1000).round());
  return matchCandidate(
    query,
    _candidate(candidateTitle, candidateArtist, duration: duration, body: body),
  ).goodMatch;
}

void main() {
  group('title and artist table', () {
    final accept = <String, (String, String, String, String)>{
      'strips remaster': (
        'Hotel California (Remaster)',
        'Eagles',
        'Hotel California',
        'Eagles',
      ),
      'strips feat': (
        'Shape of You (feat. Rapper)',
        'Ed Sheeran',
        'Shape of You',
        'Ed Sheeran',
      ),
      'folds tones and đ': ('Đừng Hỏi Em', 'Vũ', 'Dung Hoi Em', 'Vu'),
      'folds punctuation': (
        'Nơi Này Có Anh',
        'Sơn Tùng M-TP',
        'Noi Nay Co Anh',
        'Son Tung MTP',
      ),
      'same CJK': ('晴天', '周杰伦', '晴天', '周杰伦'),
      'case': ('HELLO', 'Adele', 'hello', 'ADELE'),
      'joined title': ('Nightcall', 'Kavinsky', 'Night Call', 'Kavinsky'),
      '& is and': (
        'Bridge Over Troubled Water',
        'Simon & Garfunkel',
        'Bridge Over Troubled Water',
        'Simon and Garfunkel',
      ),
      'primary artist in a remote list': (
        'Get Lucky',
        'Daft Punk feat. Pharrell Williams',
        'Get Lucky',
        'Daft Punk, Pharrell Williams',
      ),
      'live kept on both sides': (
        'Live and Let Die',
        'Paul McCartney',
        'Live and Let Die (Official Video)',
        'Paul McCartney',
      ),
      'hyphen is a space': ('Jay-Z Song', 'JAY Z', 'Jay Z Song', 'Jay-Z'),
      'fullwidth': ('ＡＢＣ', 'ＡＢＣ', 'ABC', 'ABC'),
      'tones in both': ('Mỹ Tâm Song', 'Mỹ Tâm', 'My Tam Song', 'My Tam'),
      'tone fold': ('Cô Gái M52', 'Quỳnh', 'Co Gai M52', 'Quynh'),
      'radio edit stripped': (
        'Chạy Ngay Đi (Radio Edit)',
        'Sơn Tùng',
        'Chay Ngay Di',
        'Son Tung',
      ),
      'official brackets': ('Song 【MV】', 'X', 'Song [Official Video]', 'X'),
      'CJK noise brackets': ('歌【Official】', 'X', '歌', 'X'),
      'dash suffix': ('Song - 2011 Remaster', 'X', 'Song', 'X'),
      'one edit in a long title': (
        'The Song Of Songs',
        'X',
        'The Song Of Song',
        'X',
      ),
      'library list vs remote list': ('S', 'A; B', 'S', 'A, B'),
      'whole band name': (
        'Fire',
        'Earth, Wind & Fire',
        'Fire',
        'Earth, Wind & Fire',
      ),
      'leading the': ('Yesterday', 'The Beatles', 'Yesterday', 'Beatles'),
      'apostrophe': ("Don't Stop", 'X', 'Dont Stop', 'X'),
      'x separator': ('S', 'Jay', 'S', 'Jay x Kanye'),
    };
    accept.forEach((name, c) {
      test(
        'accepts: $name',
        () => expect(_good(c.$1, c.$2, c.$3, c.$4), isTrue),
      );
    });

    final reject = <String, (String, String?, String, String)>{
      'live kept': (
        'Bohemian Rhapsody',
        'Queen',
        'Bohemian Rhapsody (Live at Wembley)',
        'Queen',
      ),
      'longer title': (
        'Yesterday',
        'The Beatles',
        'Yesterday Once More',
        'The Beatles',
      ),
      'name is a prefix': ('Đen', 'Đen', 'Đen Vâu', 'Đen'),
      'one CJK char off': ('晴天', '周杰伦', '雨天', '周杰伦'),
      'short Korean title': ('사랑', '아이유', '사랑해', '아이유'),
      'other artist': (
        'Hallelujah',
        'Jeff Buckley',
        'Hallelujah',
        'Pentatonix',
      ),
      'remix kept': (
        'Shape of You',
        'Ed Sheeran',
        'Shape of You (Stormzy Remix)',
        'Stormzy',
      ),
      'empty artist': ('Song', '', 'Song', 'X'),
      'no artist': ('Song', null, 'Song', 'X'),
      'cover by another artist': (
        'Someone Like You',
        'Adele',
        'Someone Like You',
        'Van Morrison',
      ),
      'traditional vs simplified artist': ('周杰倫', '周杰伦', '周杰倫', '周杰倫'),
      'short name vs full name': ('S', 'Vũ', 'S', 'Vũ Cát Tường'),
      'token containment is not enough': (
        'S',
        'Daft Punk',
        'S',
        'Daft Punk Tribute Band',
      ),
      'acoustic kept': ('Song', 'X', 'Song (Acoustic)', 'X'),
    };
    reject.forEach((name, c) {
      test(
        'rejects: $name',
        () => expect(_good(c.$1, c.$2, c.$3, c.$4), isFalse),
      );
    });

    test('duration: 3 s accepted inclusive, 3.001 s and 4 s rejected', () {
      expect(_good('Song', 'X', 'Song', 'X', delta: 3), isTrue);
      expect(_good('Song', 'X', 'Song', 'X', delta: -3), isTrue);
      expect(_good('Song', 'X', 'Song', 'X', delta: 3.001), isFalse);
      expect(_good('Song', 'X', 'Song', 'X', delta: 4), isFalse);
      expect(_good('Song', 'X', 'Song', 'X', delta: 5), isFalse);
    });

    test('a record without a duration fails a song that has one', () {
      final q = const LyricsQuery(
        title: 'S',
        artist: 'X',
        duration: Duration(seconds: 9),
      );
      expect(
        matchCandidate(q, _candidate('S', 'X', duration: null)).goodMatch,
        isFalse,
      );
    });

    test('lyrics or instrumental are required', () {
      // An instrumental record passes the gate; the host caches it as
      // instrumental.
      expect(_good('S', 'X', 'S', 'X', body: const LyricsBody()), isFalse);
      expect(_good('S', 'X', 'S', 'X', body: null), isFalse);
      expect(
        _good('S', 'X', 'S', 'X', body: const LyricsBody(instrumental: true)),
        isTrue,
      );
    });

    test('artist similarity boundary is 0.85', () {
      // 5 of 6 letters: 0.833; 6 of 7 letters: 0.857.
      expect(_good('S', 'eminem', 'S', 'eminen'), isFalse);
      expect(_good('S', 'sabrina', 'S', 'sabrima'), isTrue);
      expect(artistSimilarityMin, 0.85);
      expect(titleSimilarityMin, 0.85);
      expect(maxDurationDelta, const Duration(seconds: 3));
    });
  });

  group('similarity', () {
    test('counts code points, not UTF-16 units', () {
      const a =
          '\u{20000}\u{20001}\u{20002}\u{20003}\u{20004}\u{20005}\u{20006}';
      const b =
          '\u{20000}\u{20001}\u{20002}\u{20003}\u{20004}\u{20005}\u{20007}';
      expect(similarity(a, b), closeTo(6 / 7, 1e-9));
    });

    test('is 1 for equal text and 0 when too different', () {
      expect(similarity('abc', 'abc'), 1);
      expect(similarity('abc', 'xyz'), 0);
      expect(similarity('', ''), 1);
    });
  });

  group('normalizeTitle', () {
    test('strips only whitelisted noise', () {
      expect(
        normalizeTitle('Song (feat. A) [HD] {4K} - Remastered 2009'),
        'song',
      );
      expect(normalizeTitle('Song (Live)'), 'song live');
      expect(normalizeTitle('Song (Remix)'), 'song remix');
      expect(normalizeTitle('Song - Live'), 'song live');
      expect(normalizeTitle('Song (Karaoke Version)'), 'song karaoke version');
      expect(normalizeTitle('Song (Mono)'), 'song');
      expect(normalizeTitle('Rock & Roll'), 'rock and roll');
    });

    test('keeps a title that is only noise', () {
      expect(normalizeTitle('(Remaster)'), 'remaster');
      expect(normalizeTitle('Remastered - Remastered'), 'remastered');
    });

    test('keeps combining marks of other scripts', () {
      expect(normalizeTitle('เพลง'), 'เพลง');
    });
  });

  group('artist names', () {
    test('primary artist of a library tag', () {
      expect(primaryArtist('A; B'), 'A');
      expect(primaryArtist(''), isNull);
      expect(primaryArtist(null), isNull);
    });

    test('remote names split on , & x ; and feat', () {
      expect(remoteArtistNames('A, B & C x D; E feat. F'), [
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
      ]);
      expect(remoteArtistNames('Malcolm X'), ['Malcolm X']);
    });

    test('a name ending in X survives an ampersand list', () {
      expect(remoteArtistNames('Lil Nas X & Billy Ray Cyrus'), [
        'Lil Nas X',
        'Billy Ray Cyrus',
      ]);
      expect(remoteArtistNames('Skrillex x Diplo'), ['Skrillex', 'Diplo']);
      expect(
        matchCandidate(
          const LyricsQuery(
            title: 'Rodeo',
            artist: 'Lil Nas X',
            duration: Duration(seconds: 200),
          ),
          _candidate('Rodeo', 'Lil Nas X & Billy Ray Cyrus'),
        ).goodMatch,
        isTrue,
      );
    });
  });

  group('autoSearchable', () {
    LyricsQuery q({String? title = 'T', String? artist = 'A', int s = 100}) =>
        LyricsQuery(
          title: title,
          artist: artist,
          duration: Duration(seconds: s),
        );

    test('needs title, artist and duration', () {
      expect(isAutoSearchable(q()), isTrue);
      expect(isAutoSearchable(q(artist: '  ')), isFalse);
      expect(isAutoSearchable(q(artist: null)), isFalse);
      expect(isAutoSearchable(q(artist: ';')), isFalse);
      expect(isAutoSearchable(q(artist: 'Unknown Artist; B')), isFalse);
      expect(isAutoSearchable(q(title: ' ')), isFalse);
      expect(isAutoSearchable(q(s: 0)), isFalse);
      expect(
        isAutoSearchable(const LyricsQuery(title: 'T', artist: 'A')),
        isFalse,
      );
    });

    test('an unknown artist placeholder is not searched', () {
      for (final artist in [
        'Unknown Artist',
        'UNKNOWN',
        '<unknown>',
        '  unknown artist ',
      ]) {
        expect(isAutoSearchable(q(artist: artist)), isFalse, reason: artist);
      }
      expect(isAutoSearchable(q(artist: 'Unknown Mortal Orchestra')), isTrue);
    });
  });

  group('rankCandidates', () {
    const query = LyricsQuery(
      title: 'Song',
      artist: 'X',
      duration: Duration(seconds: 200),
    );

    test('good matches first, then synced, plain, instrumental, delta', () {
      final ranked = rankCandidates(query, [
        _candidate('Other', 'X', id: 1),
        _candidate(
          'Song',
          'X',
          id: 2,
          body: const LyricsBody(instrumental: true),
        ),
        _candidate('Song', 'X', id: 3, body: const LyricsBody(plain: 'p')),
        _candidate('Song', 'X', id: 4, duration: const Duration(seconds: 202)),
        _candidate('Song', 'X', id: 5, duration: const Duration(seconds: 201)),
        _candidate('Song', 'X', id: 6),
      ]);
      expect(ranked.map((m) => m.candidate.remoteId), [
        '6',
        '5',
        '4',
        '3',
        '2',
        '1',
      ]);
      expect(ranked.map((m) => m.goodMatch), [
        true,
        true,
        true,
        true,
        true,
        false,
      ]);
      expect(ranked.first.delta, Duration.zero);
    });

    test('a rejected record is never ranked', () {
      final ranked = rankCandidates(
        query,
        [_candidate('Song', 'X', id: 1), _candidate('Song', 'X', id: 2)],
        rejected: {(providerId: 'lrclib', remoteId: '1')},
      );
      expect(ranked.map((m) => m.candidate.remoteId), ['2']);
    });

    test('keepRejected lists a rejected record last and flagged', () {
      final ranked = rankCandidates(
        query,
        [_candidate('Song', 'X', id: 1), _candidate('Other', 'X', id: 2)],
        rejected: {(providerId: 'lrclib', remoteId: '1')},
        keepRejected: true,
      );
      expect(ranked.map((m) => m.candidate.remoteId), ['2', '1']);
      expect(ranked.map((m) => m.rejected), [false, true]);
      expect(ranked.last.goodMatch, isFalse);
    });

    test('a rejected record never matches, also judged alone', () {
      final c = _candidate('Song', 'X', id: 9);
      expect(matchCandidate(query, c).goodMatch, isTrue);
      expect(
        matchCandidate(
          query,
          c,
          rejected: {(providerId: 'lrclib', remoteId: '9')},
        ).goodMatch,
        isFalse,
      );
    });

    test('a duplicate text of a rejected record is rejected by hash', () {
      final twin = _candidate(
        'Song',
        'X',
        id: 2,
        body: const LyricsBody(plain: 'a'),
      );
      final other = _candidate(
        'Song',
        'X',
        id: 3,
        body: const LyricsBody(plain: 'different words'),
      );
      final hashes = {candidateContentHash(_candidate('Song', 'X'))!};
      expect(
        matchCandidate(query, twin, rejectedHashes: hashes).rejected,
        isTrue,
      );
      expect(
        matchCandidate(query, twin, rejectedHashes: hashes).goodMatch,
        isFalse,
      );
      expect(
        matchCandidate(query, other, rejectedHashes: hashes).goodMatch,
        isTrue,
      );
      final ranked = rankCandidates(query, [
        _candidate('Song', 'X'),
        twin,
        other,
      ], rejectedHashes: hashes);
      expect(ranked.map((m) => m.candidate.remoteId), ['3']);
      final kept = rankCandidates(
        query,
        [twin, other],
        rejectedHashes: hashes,
        keepRejected: true,
      );
      expect(kept.map((m) => (m.candidate.remoteId, m.rejected)), [
        ('3', false),
        ('2', true),
      ]);
    });

    test('an instrumental or empty record has no hash', () {
      expect(
        candidateContentHash(
          _candidate('S', 'X', body: const LyricsBody(instrumental: true)),
        ),
        isNull,
      );
      expect(candidateContentHash(_candidate('S', 'X', body: null)), isNull);
    });

    test('a manual search without a duration skips the duration gate', () {
      const manual = LyricsQuery(title: 'Song', artist: 'X');
      final ranked = rankCandidates(manual, [
        _candidate('Song', 'X', duration: const Duration(seconds: 900)),
      ]);
      expect(ranked.single.goodMatch, isTrue);
      expect(ranked.single.delta, isNull);
    });

    test('ties keep the given order', () {
      final ranked = rankCandidates(query, [
        _candidate('Song', 'X', id: 7),
        _candidate('Song', 'X', id: 8),
      ]);
      expect(ranked.map((m) => m.candidate.remoteId), ['7', '8']);
    });
  });

  group('cache key', () {
    String key({
      String? title = 'Hello',
      String? artist = 'Adele',
      String? album = 'Alb',
      Duration? duration = const Duration(seconds: 200),
      int? version,
    }) => onlineLyricsCacheKey(
      LyricsQuery(
        title: title,
        artist: artist,
        album: album,
        duration: duration,
      ),
      keysVersion: version ?? textKeysVersion,
    );

    test('is a sha256 hex string', () {
      expect(key(), matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('is stable across case, diacritics and featuring noise', () {
      expect(key(title: 'HELLO (feat. Z)', artist: 'ADELE; Z'), key());
      expect(key(title: 'Hèllo', artist: 'Adélé'), key());
      expect(key(duration: const Duration(milliseconds: 200400)), key());
    });

    test('a tagged key is pinned byte for byte', () {
      expect(
        key(),
        '5434a04b86df90c978116054df3f3c83a03b1a81c27c67baf2a4d26be9fe3f9a',
      );
    });

    test('a scope separates keys, none keeps the plain key', () {
      const query = LyricsQuery(duration: Duration(seconds: 200));
      expect(
        onlineLyricsCacheKey(query, scope: '/a.flac'),
        isNot(onlineLyricsCacheKey(query, scope: '/b.flac')),
      );
      expect(
        onlineLyricsCacheKey(query, scope: '/a.flac'),
        isNot(onlineLyricsCacheKey(query)),
      );
    });

    test('differs by title, album, rounded duration and keys version', () {
      expect(key(title: 'Hello2'), isNot(key()));
      expect(key(album: 'Other'), isNot(key()));
      expect(key(album: null), isNot(key()));
      expect(key(duration: const Duration(seconds: 201)), isNot(key()));
      expect(key(version: textKeysVersion + 1), isNot(key()));
    });

    test('a missing title is an empty field', () {
      expect(key(title: null), isNot(key()));
      expect(key(title: null), key(title: ''));
    });
  });
}
