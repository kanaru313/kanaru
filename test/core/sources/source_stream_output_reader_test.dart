import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/source_models.dart';
import 'package:kanaru/core/sources/source_output_reader.dart'
    show PluginOutputException;
import 'package:kanaru/core/sources/source_stream_output_reader.dart';

SourceStream _stream(Map<String, Object?> fields) => readSourceStreamOutput(
  jsonEncode({
    'url': 'https://rr1---sn-x.googlevideo.com/videoplayback?sig=1',
    'headers': {'user-agent': 'UA'},
    'mimeType': 'audio/webm',
    ...fields,
  }),
);

final _invalid = throwsA(isA<PluginOutputException>());

void main() {
  group('stream output', () {
    test('reads every field', () {
      final stream = _stream({'bitrate': 128000, 'expiresAtMs': 1790000000000});

      expect(stream.url.host, 'rr1---sn-x.googlevideo.com');
      expect(stream.headers['user-agent'], 'UA');
      expect(stream.mimeType, 'audio/webm');
      expect(stream.bitrate, 128000);
      expect(
        stream.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1790000000000, isUtc: true),
      );
    });

    test('a url that is not plain absolute https is invalid', () {
      for (final url in [
        'http://a.example.com/x',
        'https://a.example.com:443/x',
        'https://u:p@a.example.com/x',
        '/x',
        'https:///x',
        'https://a.example.com/${'a' * 8192}',
        5,
        null,
      ]) {
        expect(() => _stream({'url': url}), _invalid, reason: '$url');
      }
    });

    test('range and if-range are dropped, cookie and authorization kept', () {
      final stream = _stream({
        'headers': {
          'Range': 'bytes=0-',
          'If-Range': 'x',
          'Cookie': 'c=1',
          'Authorization': 'Bearer t',
          'Host': 'evil.example.com',
        },
      });

      expect(stream.headers.containsKey('range'), isFalse);
      expect(stream.headers.containsKey('if-range'), isFalse);
      expect(stream.headers.containsKey('host'), isFalse);
      expect(stream.headers['cookie'], 'c=1');
      expect(stream.headers['authorization'], 'Bearer t');
    });

    test('missing headers are none', () {
      final stream = readSourceStreamOutput(
        jsonEncode({'url': 'https://a.example.com/x', 'mimeType': 'audio/mp4'}),
      );

      expect(stream.headers.containsKey('range'), isFalse);
      expect(stream.headers.keys, everyElement(isNot('user-agent')));
    });

    test('bad headers are invalid', () {
      for (final headers in [
        'x',
        [],
        {'a': 5},
        {'bad name': 'v'},
        {'a': 'line\nbreak'},
        {for (var i = 0; i < 21; i++) 'h$i': 'v'},
      ]) {
        expect(
          () => _stream({'headers': headers}),
          _invalid,
          reason: '$headers',
        );
      }
      expect(
        _stream({
          'headers': {for (var i = 0; i < 20; i++) 'h$i': 'v'},
        }).headers,
        containsPair('h19', 'v'),
      );
    });

    test('the mime type must be audio, video/webm or video/mp4', () {
      for (final mime in [
        'audio/webm',
        'audio/mp4; codecs="opus"',
        'AUDIO/MPEG',
        'video/webm',
        'video/mp4;codecs=avc1',
      ]) {
        expect(_stream({'mimeType': mime}).mimeType, mime);
      }
      for (final mime in [
        'video/x-matroska',
        'text/html',
        'audio/',
        'audiox/webm',
        '',
        5,
        null,
      ]) {
        expect(() => _stream({'mimeType': mime}), _invalid, reason: '$mime');
      }
    });

    test('the four HLS types make an HLS stream, however they are spelled', () {
      for (final mime in [
        'application/vnd.apple.mpegurl',
        'application/x-mpegURL',
        'audio/mpegurl',
        'audio/x-mpegurl',
        'application/vnd.apple.mpegurl; charset=utf-8',
        '  APPLICATION/VND.APPLE.MPEGURL  ',
        ' audio/x-mpegurl ;charset=utf-8',
      ]) {
        final stream = _stream({'mimeType': mime});
        expect(stream.format, RemoteStreamFormat.hls, reason: mime);
        expect(stream.mimeType, mime);
      }
    });

    test('every other playable type stays progressive', () {
      for (final mime in [
        'audio/webm',
        'audio/mp4; codecs="opus"',
        'audio/mpeg',
        'video/webm',
        'video/mp4',
      ]) {
        expect(
          _stream({'mimeType': mime}).format,
          RemoteStreamFormat.progressive,
          reason: mime,
        );
      }
    });

    test('other application and text types are still invalid', () {
      for (final mime in [
        'application/dash+xml',
        'application/',
        'application/octet-stream',
        'text/plain',
        'application/vnd.apple.mpegurl.x',
      ]) {
        expect(() => _stream({'mimeType': mime}), _invalid, reason: mime);
      }
    });

    test('an HLS stream keeps the url, headers, bitrate and expiry rules', () {
      final stream = _stream({
        'mimeType': 'application/vnd.apple.mpegurl',
        'headers': {'Range': 'bytes=0-', 'Cookie': 'c=1'},
        'bitrate': 96000,
        'expiresAtMs': 1790000000000,
      });

      expect(stream.headers.containsKey('range'), isFalse);
      expect(stream.headers['cookie'], 'c=1');
      expect(stream.bitrate, 96000);
      expect(
        stream.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1790000000000, isUtc: true),
      );
      for (final url in [
        'http://a.example.com/x.m3u8',
        'https://a.example.com:443/x.m3u8',
        'https://u:p@a.example.com/x.m3u8',
        'https://a.example.com/${'a' * 8192}',
      ]) {
        expect(
          () => _stream({'mimeType': 'audio/mpegurl', 'url': url}),
          _invalid,
          reason: url,
        );
      }
    });

    test('bitrate 0 or anything not a positive integer is unknown', () {
      for (final bitrate in [0, -5, 1.5, '128000', null]) {
        expect(
          _stream({'bitrate': bitrate}).bitrate,
          isNull,
          reason: '$bitrate',
        );
      }
    });

    test('expiresAtMs not above 0 is unknown; expiresAt is never read', () {
      for (final ms in [0, -1, 'x', 1.5, 9e15]) {
        expect(_stream({'expiresAtMs': ms}).expiresAt, isNull, reason: '$ms');
      }
      expect(_stream({'expiresAt': 1790000000}).expiresAt, isNull);
    });
  });
}
