import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/proxy/hls/hls_snapshot.dart';
import 'package:kanaru/core/sources/proxy/hls/hls_snapshot_memory.dart';

import '../../hls/hls_test_support.dart';

HlsSnapshot snap(List<String> lines, [int rev = 1]) =>
    HlsSnapshot(parseMedia(media(lines)), rev);

const _key = '#EXT-X-KEY:METHOD=AES-128,URI="k1.key"';
const _map = '#EXT-X-MAP:URI="init.mp4"';

void main() {
  group('layout', () {
    test('the same playlist fetched again is equal, whatever its URLs', () {
      final a = snap(['#EXTINF:4,', 'a.ts', '#EXTINF:4.5,', 'b.ts']);
      final b = snap([
        '#EXTINF:4,',
        'x.ts?sig=2',
        '#EXTINF:4.5,',
        'y.ts?sig=2',
      ]);
      expect(a.layout, b.layout);
      expect(a.layout.hashCode, b.layout.hashCode);
    });

    test('a segment duration, rounded to ms, makes it unequal', () {
      final a = snap(['#EXTINF:4,', 'a.ts']);
      expect(snap(['#EXTINF:4.0004,', 'a.ts']).layout, a.layout);
      expect(snap(['#EXTINF:4.001,', 'a.ts']).layout, isNot(a.layout));
    });

    test('segment count, media sequence and discontinuity change it', () {
      final a = snap(['#EXTINF:4,', 'a.ts']);
      expect(
        snap(['#EXTINF:4,', 'a.ts', '#EXTINF:4,', 'b.ts']).layout,
        isNot(a.layout),
      );
      expect(
        snap(['#EXT-X-MEDIA-SEQUENCE:5', '#EXTINF:4,', 'a.ts']).layout,
        isNot(a.layout),
      );
      expect(
        snap(['#EXT-X-DISCONTINUITY', '#EXTINF:4,', 'a.ts']).layout,
        isNot(a.layout),
      );
    });

    test('a key index change makes it unequal', () {
      final one = snap([_key, '#EXTINF:4,', 'a.ts', '#EXTINF:4,', 'b.ts']);
      final two = snap([
        _key,
        '#EXTINF:4,',
        'a.ts',
        '#EXT-X-KEY:METHOD=AES-128,URI="k2.key"',
        '#EXTINF:4,',
        'b.ts',
      ]);
      expect(one.keys, hasLength(1));
      expect(two.keys, hasLength(2));
      expect(two.layout, isNot(one.layout));
      expect(
        snap(['#EXTINF:4,', 'a.ts', '#EXTINF:4,', 'b.ts']).layout,
        isNot(one.layout),
      );
    });

    test('an init index change makes it unequal', () {
      final one = snap([_map, '#EXTINF:4,', 'a.m4s', '#EXTINF:4,', 'b.m4s']);
      final two = snap([
        _map,
        '#EXTINF:4,',
        'a.m4s',
        '#EXT-X-MAP:URI="init2.mp4"',
        '#EXTINF:4,',
        'b.m4s',
      ]);
      expect(two.inits, hasLength(2));
      expect(two.layout, isNot(one.layout));
    });

    test('keys are numbered by URI, the IV is part of the segment state', () {
      String keyLine(int n) =>
          '#EXT-X-KEY:METHOD=AES-128,URI="k.key",IV=0x${n.toRadixString(16).padLeft(32, '0')}';
      final a = snap([
        keyLine(1),
        '#EXTINF:4,',
        'a.ts',
        keyLine(2),
        '#EXTINF:4,',
        'b.ts',
      ]);
      expect(a.keys, hasLength(1));
      expect(a.layout.keyCount, 1);
      expect(a.layout.segments.map((e) => e.keyIndex), [0, 0]);
      // The same file with another IV on the second segment is another layout.
      final b = snap([
        keyLine(1),
        '#EXTINF:4,',
        'a.ts',
        keyLine(3),
        '#EXTINF:4,',
        'b.ts',
      ]);
      expect(b.layout, isNot(a.layout));
      expect(
        snap([
          keyLine(1),
          '#EXTINF:4,',
          'x.ts',
          keyLine(2),
          '#EXTINF:4,',
          'y.ts',
        ]).layout,
        a.layout,
      );
    });

    test('a derived IV and an explicit one are different states', () {
      final derived = snap([_key, '#EXTINF:4,', 'a.ts']);
      final explicit = snap([
        '#EXT-X-KEY:METHOD=AES-128,URI="k1.key",'
            'IV=0x00000000000000000000000000000001',
        '#EXTINF:4,',
        'a.ts',
      ]);
      expect(explicit.layout, isNot(derived.layout));
    });

    test('where the init sits relative to a key makes it unequal', () {
      final clearInit = snap([_map, _key, '#EXTINF:4,', 'a.m4s']);
      final encryptedInit = snap([_key, _map, '#EXTINF:4,', 'a.m4s']);
      expect(clearInit.keys, hasLength(1));
      expect(encryptedInit.keys, hasLength(1));
      expect(clearInit.layout.segments, encryptedInit.layout.segments);
      expect(clearInit.layout.inits.single.keyIndex, isNull);
      expect(encryptedInit.layout.inits.single.keyIndex, 0);
      expect(clearInit.layout, isNot(encryptedInit.layout));
      expect(clearInit.layout.hashCode, isNot(encryptedInit.layout.hashCode));
    });

    test('the key an init section is read under is numbered too', () {
      final s = snap([
        _key,
        _map,
        '#EXT-X-KEY:METHOD=AES-128,URI="k2.key"',
        '#EXTINF:4,',
        'a.m4s',
      ]);
      expect(s.keys.map((u) => u.pathSegments.last), ['k1.key', 'k2.key']);
      expect(s.layout.inits.single.keyIndex, 0);
      expect(s.layout.segments.single.keyIndex, 1);
    });

    test('a key that comes back keeps its index', () {
      final s = snap([
        _key,
        '#EXTINF:4,',
        'a.ts',
        '#EXT-X-KEY:METHOD=NONE',
        '#EXTINF:4,',
        'b.ts',
        _key,
        '#EXTINF:4,',
        'c.ts',
      ]);
      expect(s.layout.segments.map((e) => e.keyIndex), [0, null, 0]);
      expect(s.keys, hasLength(1));
    });
  });

  group('memory', () {
    final layout = snap(['#EXTINF:4,', 'a.ts']).layout;

    test('revs count up from 1 and are remembered with their key', () {
      final memory = HlsSnapshotMemory();
      expect(memory.remember('a', layout), 1);
      expect(memory.remember('b', layout), 2);
      expect(memory.layoutOf('a', 1), layout);
      expect(memory.layoutOf('a', 2), isNull);
      expect(memory.layoutOf('b', 3), isNull);
    });

    test('only the last 64 snapshots are remembered', () {
      final memory = HlsSnapshotMemory();
      for (var i = 0; i < hlsRememberedSnapshots + 1; i++) {
        memory.remember('k', layout);
      }
      expect(memory.layoutOf('k', 1), isNull);
      expect(memory.layoutOf('k', 2), layout);
      expect(memory.layoutOf('k', hlsRememberedSnapshots + 1), layout);
    });
  });
}
