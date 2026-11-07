import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/hls/hls_attribute_list.dart';
import 'package:kanaru/core/sources/hls/hls_refusal.dart';

import 'hls_test_support.dart';

void main() {
  test('null and empty text have no attributes', () {
    expect(parseHlsAttributeList(null), isEmpty);
    expect(parseHlsAttributeList(''), isEmpty);
  });

  test('quoted strings may hold commas; unquoted values are plain', () {
    final attributes = parseHlsAttributeList(
      'BANDWIDTH=128000,CODECS="mp4a.40.2,avc1.64001f",NAME="a, b"',
    );
    expect(attributes, {
      'BANDWIDTH': '128000',
      'CODECS': 'mp4a.40.2,avc1.64001f',
      'NAME': 'a, b',
    });
  });

  test('unknown attributes are kept; hex and decimal values are text', () {
    final attributes = parseHlsAttributeList(
      'IV=0xAB12,X-CUSTOM=1.5,RESOLUTION=640x360,METHOD=AES-128',
    );
    expect(attributes['IV'], '0xAB12');
    expect(attributes['X-CUSTOM'], '1.5');
    expect(attributes['RESOLUTION'], '640x360');
    expect(attributes['METHOD'], 'AES-128');
  });

  test('spaces around a comma are tolerated', () {
    expect(parseHlsAttributeList('A=1, B="x" ,C=3'), {
      'A': '1',
      'B': 'x',
      'C': '3',
    });
  });

  test('a repeated attribute is invalid', () {
    expectRefused(
      () => parseHlsAttributeList('A=1,A=2'),
      HlsRefusalKind.invalid,
    );
  });

  test('an unterminated quote is invalid', () {
    expectRefused(
      () => parseHlsAttributeList('URI="abc,B=1'),
      HlsRefusalKind.invalid,
    );
  });

  test('a missing =, a bad name and text after a quote are invalid', () {
    for (final text in ['A', '=1', 'a=1', 'A="x"y', 'A=b"c']) {
      expectRefused(() => parseHlsAttributeList(text), HlsRefusalKind.invalid);
    }
  });
}
