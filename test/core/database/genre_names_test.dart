import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/genre_names.dart';

void main() {
  test('a single genre stays as it is', () {
    expect(splitGenres('Rock'), ['Rock']);
  });

  test('splits on a semicolon and trims', () {
    expect(splitGenres('Rock; Pop ;Jazz'), ['Rock', 'Pop', 'Jazz']);
  });

  test('repeats by key are dropped, the first spelling stays', () {
    expect(splitGenres('rock;ROCK; Rock'), ['rock']);
  });

  test('empty parts and null give nothing', () {
    expect(splitGenres('  ; '), isEmpty);
    expect(splitGenres(''), isEmpty);
    expect(splitGenres(null), isEmpty);
    expect(splitGenres('Rock;;'), ['Rock']);
  });

  test('a part with only invisible characters is not a genre', () {
    expect(splitGenres('Rock;​'), ['Rock']);
  });

  test('case and accents fold into one key', () {
    expect(genreKey('Nhạc Trẻ'), genreKey('nhac tre'));
    expect(genreKey('Rock'), isNot(genreKey('Pop')));
  });

  test('a slash does not split by default', () {
    expect(splitGenres('Rock/Pop'), ['Rock/Pop']);
  });

  test('custom separators split on any of them', () {
    expect(
      splitGenres(
        'Rock/Pop; Jazz',
        rules: const SplitRules(separators: ['/', ';'], keepWhole: []),
      ),
      ['Rock', 'Pop', 'Jazz'],
    );
  });

  test('separators are literal text, not a pattern', () {
    expect(
      splitGenres(
        'Rock|Pop.Jazz',
        rules: const SplitRules(separators: ['|'], keepWhole: []),
      ),
      ['Rock', 'Pop.Jazz'],
    );
    expect(
      splitGenres(
        'a.b',
        rules: const SplitRules(separators: ['.'], keepWhole: []),
      ),
      ['a', 'b'],
    );
    expect(
      splitGenres(
        'axb',
        rules: const SplitRules(separators: ['.'], keepWhole: []),
      ),
      ['axb'],
    );
  });

  test('no usable separator keeps the text whole', () {
    expect(
      splitGenres(
        'Rock; Pop',
        rules: const SplitRules(separators: [], keepWhole: []),
      ),
      ['Rock; Pop'],
    );
    expect(
      splitGenres(
        'Rock; Pop',
        rules: const SplitRules(separators: [''], keepWhole: []),
      ),
      ['Rock; Pop'],
    );
  });
}
