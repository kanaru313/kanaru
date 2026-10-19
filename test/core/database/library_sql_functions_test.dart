import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/artist_names.dart';
import 'package:kanaru/core/database/library_sql_functions.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database db;

  setUp(() {
    db = sqlite3.openInMemory();
    registerLibrarySqlFunctions(db);
  });
  tearDown(() => db.close());

  Object? sql(String expression, [List<Object?> args = const []]) =>
      db.select('SELECT $expression AS v', args).single['v'];

  const tags = [
    'Ban nhạc Hương Mùa Hè;SUNI Hạ Linh',
    'Chau Khai Phong feat. Trịnh Đình Quang',
    'AC/DC',
    'A [ft. B; C]',
    'Simon & Garfunkel',
    'ĐEN; đen',
    ' ; ',
  ];

  test('artist keys in SQL are the Dart keys', () {
    for (final tag in tags) {
      final keys = artistKeys(tag);
      expect(
        sql('kanaru_artist_keys(?)', [tag]),
        keys.isEmpty ? null : ';${keys.join(';')};',
        reason: tag,
      );
      expect(
        sql('kanaru_first_artist(?)', [tag]),
        splitArtists(tag).firstOrNull,
        reason: tag,
      );
    }
    expect(sql('kanaru_artist_keys(NULL)'), isNull);
  });

  test('matching a key needs the whole name', () {
    bool credits(String tag, String key) =>
        sql("instr(kanaru_artist_keys(?), ';' || ? || ';') > 0", [tag, key]) ==
        1;
    expect(credits('Ann; Anna', 'ann'), isTrue);
    expect(credits('Anna', 'ann'), isFalse);
    expect(credits('X feat. Ann', 'ann'), isTrue);
  });

  test('album keys in SQL are the Dart keys', () {
    for (final albumArtist in [null, 'Various Artists', 'A / B']) {
      for (final artist in [null, ...tags]) {
        expect(
          sql('kanaru_album_artist_key(?, ?)', [albumArtist, artist]),
          albumArtistKey(albumArtist, artist),
          reason: '$albumArtist | $artist',
        );
      }
    }
    expect(albumArtistKey(null, 'X feat. Y'), 'x');
    expect(albumArtistKey('A / B', 'X'), 'a; b');
    expect(albumArtistKey(null, null), '');
    expect(sql('kanaru_album_title_key(?)', ['Ánh Best']), 'ánh best');
    expect(sql('kanaru_album_title_key(NULL)'), isNull);
  });
}
