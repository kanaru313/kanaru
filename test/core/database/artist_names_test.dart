import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/artist_names.dart';

void main() {
  test('splits on the exact separator only', () {
    expect(splitArtists('A; B'), ['A', 'B']);
    expect(splitArtists('A'), ['A']);
    expect(splitArtists('A;B'), ['A;B']);
  });

  test('gives no names for null, empty or empty parts', () {
    expect(splitArtists(null), isEmpty);
    expect(splitArtists(''), isEmpty);
    expect(splitArtists('; A; '), ['A']);
  });
}
