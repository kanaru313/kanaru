import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/extra_tags.dart';

void main() {
  test('encode always writes the version and omits null keys', () {
    expect(jsonDecode(encodeExtraTags()), {'v': extraTagsVersion});
    expect(jsonDecode(encodeExtraTags(releaseDate: '2019-07-15')), {
      'v': extraTagsVersion,
      'releaseDate': '2019-07-15',
    });
  });

  test('encode drops a value that would pass the size cap', () {
    final json = encodeExtraTags(releaseDate: 'x' * maxExtraTagsBytes);
    expect(jsonDecode(json), {'v': extraTagsVersion});
    expect(json.length, lessThan(maxExtraTagsBytes));
  });

  test('decode reads what encode wrote', () {
    expect(
      decodeExtraTags(encodeExtraTags(releaseDate: '20190715')).releaseDate,
      '20190715',
    );
    expect(decodeExtraTags(encodeExtraTags()).releaseDate, isNull);
  });

  test('decode is tolerant of null, junk, wrong shapes and unknown keys', () {
    for (final bad in [
      null,
      '',
      'not json',
      '[1,2]',
      '"text"',
      '42',
      '{"v":1,"releaseDate":5}',
      '{"v":1,"releaseDate":null}',
    ]) {
      expect(decodeExtraTags(bad).releaseDate, isNull, reason: '$bad');
    }
    expect(
      decodeExtraTags('{"v":9,"releaseDate":"2001","future":[1]}').releaseDate,
      '2001',
    );
  });
}
