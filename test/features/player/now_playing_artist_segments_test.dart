import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/artist_names.dart';
import 'package:kanaru/features/player/now_playing/now_playing_artist_segments.dart';

void main() {
  List<(String, int?)> split(String tag, {SplitRules? rules}) => [
    for (final s in artistLineSegments(
      tag,
      splitArtists(tag, rules: rules ?? defaultArtistRules),
    ))
      (s.text, s.artist),
  ];

  test('one name is one link', () {
    expect(split('Ann'), [('Ann', 0)]);
  });

  test('separators are plain text between links', () {
    expect(split('Ann; Bob'), [('Ann', 0), ('; ', null), ('Bob', 1)]);
    expect(split('Ann, Bob'), [('Ann', 0), (', ', null), ('Bob', 1)]);
    expect(split('Ann feat. Bob'), [('Ann', 0), (' feat. ', null), ('Bob', 1)]);
  });

  test('a bracketed featuring part keeps its brackets plain', () {
    expect(split('Ann (feat. Bob)'), [
      ('Ann', 0),
      (' (feat. ', null),
      ('Bob', 1),
      (')', null),
    ]);
  });

  test('a name with an ampersand stays one link', () {
    expect(split('Simon & Garfunkel'), [('Simon & Garfunkel', 0)]);
  });

  test('a custom separator splits the ampersand', () {
    const rules = SplitRules(separators: [';', '&'], keepWhole: []);
    expect(split('Simon & Garfunkel', rules: rules), [
      ('Simon', 0),
      (' & ', null),
      ('Garfunkel', 1),
    ]);
  });

  test('a keep-whole name is one link', () {
    expect(split('AC/DC; Bob'), [('AC/DC', 0), ('; ', null), ('Bob', 1)]);
  });

  test('surrounding spaces are plain', () {
    expect(split(' Ann '), [(' ', null), ('Ann', 0), (' ', null)]);
  });

  test('a repeated name leaves its second mention plain', () {
    expect(split('A; B; A'), [('A', 0), ('; ', null), ('B', 1), ('; A', null)]);
  });

  test('names containing each other resolve in order', () {
    expect(split('Ann feat. Annie'), [
      ('Ann', 0),
      (' feat. ', null),
      ('Annie', 1),
    ]);
    expect(split('Bobby, Bob'), [('Bobby', 0), (', ', null), ('Bob', 1)]);
  });

  test('a name missing from the tag makes the whole tag one link', () {
    expect(
      [
        for (final s in artistLineSegments('Zed', ['Ann', 'Bob']))
          (s.text, s.artist),
      ],
      [('Zed', 0)],
    );
    expect(
      [
        for (final s in artistLineSegments('Ann; Bob', ['Bob', 'Ann']))
          (s.text, s.artist),
      ],
      [('Ann; Bob', 0)],
    );
  });

  test('no names give the whole tag as plain text', () {
    expect(
      [for (final s in artistLineSegments('Ann', [])) (s.text, s.artist)],
      [('Ann', null)],
    );
  });
}
