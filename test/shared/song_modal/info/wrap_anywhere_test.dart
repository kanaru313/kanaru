import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/song_modal/info/wrap_anywhere.dart';

void main() {
  test('short words and sentences are left alone', () {
    expect(wrapAnywhere('Hello world'), 'Hello world');
    expect(wrapAnywhere('a' * 24), 'a' * 24);
  });

  test('a long unbroken token gets a break point between characters', () {
    final out = wrapAnywhere('a' * 25);
    expect(out.replaceAll(zeroWidthSpace, ''), 'a' * 25);
    expect(out.split(zeroWidthSpace), hasLength(25));
  });

  test('only the long token changes; spaces stay', () {
    final path = '/home/user/Music/${'x' * 10}/track.flac';
    final out = wrapAnywhere('see $path now');
    expect(out.startsWith('see '), isTrue);
    expect(out.endsWith(' now'), isTrue);
    expect(out.replaceAll(zeroWidthSpace, ''), 'see $path now');
    expect(out, contains(zeroWidthSpace));
  });

  test('characters outside the BMP are not split in half', () {
    final text = '\u{1F3B5}' * 30;
    final out = wrapAnywhere(text);
    expect(out.split(zeroWidthSpace), hasLength(30));
    expect(out.replaceAll(zeroWidthSpace, ''), text);
  });
}
