import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/cover_paths.dart';

void main() {
  final hash = 'ab${'0' * 62}';
  final key = 'ab/$hash.jpg';

  test('joins a well-formed key to the folder', () {
    expect(coverPath('/c/covers/512', key), '/c/covers/512/$key');
  });

  test('gives null without a folder or a key', () {
    expect(coverPath(null, key), isNull);
    expect(coverPath('/c', null), isNull);
  });

  test('refuses keys that do not look like thumbnails', () {
    for (final bad in [
      '../$hash.jpg',
      'cd/$hash.jpg',
      'ab/$hash.png',
      'AB/${hash.toUpperCase()}.jpg',
      'ab/../../etc/passwd',
      'ab/${hash}0.jpg',
      '',
    ]) {
      expect(isCoverKey(bad), isFalse, reason: bad);
      expect(coverPath('/c', bad), isNull, reason: bad);
    }
    expect(isCoverKey(key), isTrue);
  });
}
