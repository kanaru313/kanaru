import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_match.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';

const _body = LyricsBody(syncedLrc: '[00:01.00] a', plain: 'a');

/// Whether a record by [remote] passes the gate for a song tagged [local].
bool _good(String? local, String remote) => matchCandidate(
  LyricsQuery(
    title: 'Song',
    artist: local,
    duration: const Duration(seconds: 200),
  ),
  LyricsCandidate(
    providerId: 'lrclib',
    remoteId: '1',
    title: 'Song',
    artist: remote,
    duration: const Duration(seconds: 200),
    body: _body,
  ),
).goodMatch;

void main() {
  group('any artist matches', () {
    final accepted = {
      'reversed order, other artist only': (
        'Ngân Ngân, Châu Khải Phong',
        'Chau Khai Phong',
      ),
      'second local artist in a remote pair': (
        'Billy Ray Cyrus, Lil Nas X',
        'Lil Nas X',
      ),
      'shuffled lists': ('Skrillex; Diplo', 'Diplo & Skrillex'),
      'first local artist, as before': ('Daft Punk; Pharrell', 'Daft Punk'),
      'whole string': ('Earth, Wind & Fire', 'Earth, Wind & Fire'),
      'similar spelling': ('A Band; sabrina', 'sabrima'),
    };
    accepted.forEach((name, c) {
      test('accepts: $name', () => expect(_good(c.$1, c.$2), isTrue));
    });

    final rejected = {
      'no shared artist': ('Sơn Tùng M-TP', 'Mỹ Tâm'),
      'no shared artist in lists': ('Sơn Tùng M-TP; Hà', 'Mỹ Tâm, Đức Phúc'),
      'short names differ': ('B', 'BB'),
      'short name in a list': ('Xyz Band; B', 'BB'),
      'two letters differ by one': ('Ab', 'Ac'),
      'various artists remote': ('Daft Punk', 'Various Artists'),
      'various artists local': ('Various Artists', 'Daft Punk'),
      'various artists both': ('Various Artists', 'Various Artists'),
      'va both': ('VA', 'V.A'),
      'vietnamese placeholder': ('Nhiều ca sĩ', 'Nhieu Ca Si'),
      'unknown in a list only': ('Unknown Artist; Other', 'Unknown'),
    };
    rejected.forEach((name, c) {
      test('rejects: $name', () => expect(_good(c.$1, c.$2), isFalse));
    });

    test('equal short names match', () => expect(_good('B', 'B'), isTrue));

    test('a placeholder beside a real name does not hide the name', () {
      expect(_good('Various Artists; Diplo', 'Skrillex, Diplo'), isTrue);
    });
  });

  group('placeholders', () {
    test('every spelling is unknown', () {
      for (final name in [
        'Unknown Artist',
        '<unknown>',
        'Various Artists',
        'Various Artist',
        'Various',
        'various artists',
        'Nhiều ca sĩ',
        'nhieu ca si',
        'VA',
        'V.A.',
      ]) {
        expect(isUnknownArtist(name), isTrue, reason: name);
      }
      expect(isUnknownArtist('Vũ'), isFalse);
      expect(isUnknownArtist('Valerie'), isFalse);
    });

    test('a song tagged only Various Artists is not auto searchable', () {
      expect(
        isAutoSearchable(
          const LyricsQuery(
            title: 'T',
            artist: 'Various Artists',
            duration: Duration(seconds: 100),
          ),
        ),
        isFalse,
      );
    });
  });
}
