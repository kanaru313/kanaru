import 'dart:math';

import 'package:drift/drift.dart';
import 'package:kanaru/core/database/library_database.dart';

const _onsets = [
  '',
  'b',
  'c',
  'd',
  'đ',
  'h',
  'l',
  'm',
  'n',
  'ph',
  's',
  't',
  'th',
  'v',
  'k',
  'r',
];
const _vowels = [
  'a',
  'ă',
  'â',
  'e',
  'ê',
  'i',
  'o',
  'ô',
  'ơ',
  'u',
  'ư',
  'y',
  'ai',
  'ie',
  'ou',
];
const _tones = ['', 'ì', 'á', 'ả', 'ã', 'ạ', 'ồ', 'ế'];
const _codas = ['', 'n', 'm', 'ng', 't', 'c', 'nh', 'r', 'l', 's'];

/// A few thousand distinct words, Vietnamese-looking and plain ASCII ones.
List<String> benchVocabulary(Random rnd, {int size = 4000}) {
  final words = <String>{'son', 'tung', 'sơn', 'tùng', 'đi', 'the', 'love'};
  while (words.length < size) {
    final syllables = 1 + rnd.nextInt(2);
    final buffer = StringBuffer();
    for (var i = 0; i < syllables; i++) {
      buffer
        ..write(_onsets[rnd.nextInt(_onsets.length)])
        ..write(_vowels[rnd.nextInt(_vowels.length)])
        ..write(_tones[rnd.nextInt(_tones.length)])
        ..write(_codas[rnd.nextInt(_codas.length)]);
    }
    words.add(buffer.toString());
  }
  return words.toList();
}

/// [count] rows shaped like a real library: ~3k artists (a fifth with a
/// co-credit), ~4k albums, 10 genres of which `Pop` covers ~40%, titles of
/// 1-5 words with common words like "the" and "đi" often present.
List<TracksCompanion> benchSearchRows(int rootId, {int count = 50000}) {
  final rnd = Random(7);
  final vocab = benchVocabulary(rnd);
  // Squared index: a few words are far more common than the rest.
  String word() => vocab[(pow(rnd.nextDouble(), 2) * vocab.length).floor()];
  String phrase(int min, int max) => List.generate(
    min + rnd.nextInt(max - min + 1),
    (_) => word(),
  ).map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  final artists = List.generate(3000, (_) => phrase(1, 3));
  final albums = List.generate(
    4000,
    (i) => (phrase(1, 4), artists[rnd.nextInt(artists.length)]),
  );
  const genres = [
    'Pop',
    'Rock',
    'Hip Hop',
    'Jazz',
    'Classical',
    'Electronic',
    'Folk',
    'Ballad',
    'V-Pop',
    'Blues',
  ];
  return [
    for (var i = 0; i < count; i++)
      () {
        final album = albums[rnd.nextInt(albums.length)];
        final artist = rnd.nextInt(5) == 0
            ? '${album.$2}; ${artists[rnd.nextInt(artists.length)]}'
            : album.$2;
        return TracksCompanion.insert(
          rootId: rootId,
          path: '/m/$i.flac',
          mtimeMs: 1,
          sizeBytes: 1,
          title: '${rnd.nextInt(20) == 0 ? 'The ' : ''}${phrase(1, 5)}',
          artist: Value(artist),
          album: Value(i % 25 == 0 ? null : album.$1),
          albumArtist: Value(i % 3 == 0 ? null : album.$2),
          genre: Value(
            rnd.nextDouble() < 0.4 ? 'Pop' : genres[rnd.nextInt(genres.length)],
          ),
          addedAt: i,
          updatedAt: i,
        );
      }(),
  ];
}
