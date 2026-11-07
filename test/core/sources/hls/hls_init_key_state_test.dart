import 'package:flutter_test/flutter_test.dart';

import 'hls_test_support.dart';

const _k1 = '#EXT-X-KEY:METHOD=AES-128,URI="k1.key"';
const _k2 = '#EXT-X-KEY:METHOD=AES-128,URI="k2.key"';
const _none = '#EXT-X-KEY:METHOD=NONE';
const _map = '#EXT-X-MAP:URI="init.mp4"';

void main() {
  group('the key in force at an EXT-X-MAP line', () {
    test('a MAP before the KEY is read in clear', () {
      final s = parseMedia(media([_map, _k1, '#EXTINF:4,', 'a.m4s']))
          .segments
          .single;
      expect(s.init!.key, isNull);
      expect(s.key!.uri.pathSegments.last, 'k1.key');
    });

    test('a MAP after the KEY is read under it', () {
      final s = parseMedia(media([_k1, _map, '#EXTINF:4,', 'a.m4s']))
          .segments
          .single;
      expect(s.init!.key, s.key);
      expect(s.init!.key, isNotNull);
    });

    test('a later MAP under the same key has the same key', () {
      final segments = parseMedia(
        media([
          _k1,
          _map,
          '#EXTINF:4,',
          'a.m4s',
          '#EXT-X-MAP:URI="init2.mp4"',
          '#EXTINF:4,',
          'b.m4s',
        ]),
      ).segments;
      expect(segments[0].init!.key, segments[1].init!.key);
      expect(segments[1].init!.key, segments[1].key);
      expect(segments[0].init, isNot(segments[1].init));
    });

    test('METHOD=NONE before the MAP means a clear init', () {
      final s = parseMedia(
        media([_k1, _none, _map, _k1, '#EXTINF:4,', 'a.m4s']),
      ).segments.single;
      expect(s.init!.key, isNull);
      expect(s.key, isNotNull);
    });

    test('a key rotation keeps the init section under its own key', () {
      final segments = parseMedia(
        media([_k1, _map, '#EXTINF:4,', 'a.m4s', _k2, '#EXTINF:4,', 'b.m4s']),
      ).segments;
      expect(segments[0].init, segments[1].init);
      expect(segments[1].init!.key!.uri.pathSegments.last, 'k1.key');
      expect(segments[1].key!.uri.pathSegments.last, 'k2.key');
    });

    test('the same init under another key is another init section', () {
      final segments = parseMedia(
        media([_map, '#EXTINF:4,', 'a.m4s', _k1, _map, '#EXTINF:4,', 'b.m4s']),
      ).segments;
      expect(segments[0].init, isNot(segments[1].init));
    });
  });
}
