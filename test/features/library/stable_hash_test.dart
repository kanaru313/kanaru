import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/widgets/stable_hash.dart';

void main() {
  test('matches the FNV-1a 32-bit reference values', () {
    expect(fnv1a(''), 0x811c9dc5);
    expect(fnv1a('a'), 0xe40c292c);
    expect(fnv1a('foobar'), 0xbf9cf968);
  });

  test('hashes UTF-8 bytes and stays 32-bit', () {
    expect(fnv1a('漢字😀'), inInclusiveRange(0, 0xffffffff));
    expect(fnv1a('é'), isNot(fnv1a('e')));
  });
}
