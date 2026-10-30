import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_output_reader.dart';

PluginSearchOutput _search(Object? data) =>
    readSearchOutput(jsonEncode(data), providerId: 'p1');

Matcher get _badOutput => throwsA(isA<PluginOutputException>());

void main() {
  group('search output', () {
    test('a full item becomes a candidate of the provider', () {
      final out = _search([
        {
          'id': 'abc',
          'title': 'Song',
          'artist': 'Artist',
          'album': 'Alb',
          'durationMs': 200500,
        },
      ]);
      final c = out.candidates.single;
      expect(
        (c.providerId, c.remoteId, c.title, c.artist, c.album, c.duration),
        (
          'p1',
          'abc',
          'Song',
          'Artist',
          'Alb',
          const Duration(milliseconds: 200500),
        ),
      );
      expect(c.body, isNull);
      expect(out.dropped, isEmpty);
    });

    test('inline lyrics become the body, synced when stamped', () {
      final out = _search([
        {'id': '1', 'title': 'a', 'artist': 'b', 'lyrics': '[00:01.00] hi'},
        {'id': '2', 'title': 'a', 'artist': 'b', 'lyrics': 'just words'},
        {'id': '3', 'title': 'a', 'artist': 'b', 'lyrics': '  '},
      ]);
      expect(out.candidates[0].body!.syncedLrc, '[00:01.00] hi');
      expect(out.candidates[1].body!.plain, 'just words');
      expect(out.candidates[2].body, isNull);
    });

    test('a whole-number double duration is accepted', () {
      final out = readSearchOutput(
        '[{"id":"1","title":"a","artist":"b","durationMs":1500.0}]',
        providerId: 'p1',
      );
      expect(
        out.candidates.single.duration,
        const Duration(milliseconds: 1500),
      );
    });

    test('album null or blank is no album', () {
      final out = _search([
        {'id': '1', 'title': 'a', 'artist': 'b', 'album': null},
        {'id': '2', 'title': 'a', 'artist': 'b', 'album': ' '},
      ]);
      expect(out.candidates.map((c) => c.album), [null, null]);
    });

    test('an invalid item is dropped with a numbered reason', () {
      final good = {'id': '1', 'title': 'a', 'artist': 'b'};
      final out = _search([
        good,
        {'id': '2', 'title': 'a'},
        'text',
        {'id': '', 'title': 'a', 'artist': 'b'},
        {'id': 'x' * 257, 'title': 'a', 'artist': 'b'},
        {'id': '3', 'title': ' ', 'artist': 'b'},
        {'id': '4', 'title': 'a', 'artist': 'b', 'durationMs': 0},
        {'id': '5', 'title': 'a', 'artist': 'b', 'durationMs': 1.5},
        {'id': '6', 'title': 'a', 'artist': 'b', 'durationMs': '90'},
        {'id': '7', 'title': 'a', 'artist': 'b', 'album': 3},
        {'id': '8', 'title': 'a', 'artist': 'b', 'lyrics': 3},
        {'id': 9, 'title': 'a', 'artist': 'b'},
        good,
      ]);
      expect(out.candidates, hasLength(2));
      expect(out.dropped, [
        'result #2: "artist" must be a non-empty string',
        'result #3: must be an object',
        startsWith('result #4: "id" must be a non-empty string'),
        startsWith('result #5: "id" must be a non-empty string'),
        'result #6: "title" must be a non-empty string',
        'result #7: "durationMs" must be an integer above 0',
        'result #8: "durationMs" must be an integer above 0',
        'result #9: "durationMs" must be an integer above 0',
        'result #10: "album" must be a string',
        'result #11: "lyrics" must be a string',
        startsWith('result #12: "id" must'),
      ]);
    });

    test('an id of 256 characters is kept', () {
      final out = _search([
        {'id': 'x' * 256, 'title': 'a', 'artist': 'b'},
      ]);
      expect(out.candidates, hasLength(1));
    });

    test('inline lyrics over 1 MiB drop the item', () {
      final out = _search([
        {
          'id': '1',
          'title': 'a',
          'artist': 'b',
          'lyrics': 'x' * (1024 * 1024 + 1),
        },
      ]);
      expect(out.candidates, isEmpty);
      expect(out.dropped.single, 'result #1: "lyrics" is larger than 1 MiB');
    });

    test('a duration of 24 h or more is ignored, the item kept', () {
      final out = _search([
        {'id': '1', 'title': 'a', 'artist': 'b', 'durationMs': 86400000},
        {
          'id': '2',
          'title': 'a',
          'artist': 'b',
          'durationMs': 9007199254740991,
        },
        {'id': '3', 'title': 'a', 'artist': 'b', 'durationMs': 86399999},
      ]);
      expect(out.candidates.map((c) => c.duration), [
        null,
        null,
        const Duration(milliseconds: 86399999),
      ]);
      expect(out.dropped, isEmpty);
    });

    test('an empty array is a valid, empty answer', () {
      final out = _search(<Object>[]);
      expect(out.candidates, isEmpty);
      expect(out.dropped, isEmpty);
    });

    for (final bad in ['null', '{}', '"x"', '3', 'not json', '']) {
      test('output $bad is a bad shape', () {
        expect(() => readSearchOutput(bad, providerId: 'p1'), _badOutput);
      });
    }
  });

  group('lyrics output', () {
    LyricsBody? read(Object? data) => readLyricsOutput(jsonEncode(data));

    test('null is no lyrics', () {
      expect(readLyricsOutput('null'), isNull);
    });

    test('instrumental', () {
      final body = read({'instrumental': true})!;
      expect(body.instrumental, isTrue);
      expect(body.hasLyrics, isFalse);
    });

    test('instrumental true wins over data', () {
      expect(
        read({'instrumental': true, 'data': 'words'})!.instrumental,
        isTrue,
      );
    });

    test('type lrc is synced even without stamps, txt is plain even with', () {
      expect(read({'data': 'words', 'type': 'lrc'})!.syncedLrc, 'words');
      expect(
        read({'data': '[00:01.00] x', 'type': 'txt'})!.plain,
        '[00:01.00] x',
      );
    });

    test('a missing or unknown type is detected from a stamp', () {
      expect(read({'data': '[01:02.30] x'})!.syncedLrc, '[01:02.30] x');
      expect(
        read({'data': '[01:02] x', 'type': 'weird'})!.syncedLrc,
        isNotNull,
      );
      expect(read({'data': 'no stamps [ar:x]'})!.plain, 'no stamps [ar:x]');
    });

    test('blank data and instrumental false is no lyrics', () {
      expect(read({'data': ' \n', 'instrumental': false}), isNull);
    });

    test('data of exactly 1 MiB passes, one more byte is refused', () {
      final ok = 'a' * (1024 * 1024);
      expect(read({'data': ok})!.plain, hasLength(1024 * 1024));
      expect(() => read({'data': '${ok}a'}), _badOutput);
    });

    test('multi-byte text is measured in UTF-8 bytes', () {
      // 400k three-byte characters are 1.2 MB.
      expect(() => read({'data': 'あ' * 400000}), _badOutput);
      expect(read({'data': 'あ' * 300000}), isNotNull);
    });

    for (final bad in [
      <String, Object?>{},
      {'data': 5},
      {'data': null},
      {'data': 'x', 'type': 3},
      {'instrumental': 'yes', 'data': 'x'},
      [1],
      'text',
      7,
    ]) {
      test('${jsonEncode(bad)} is a bad shape', () {
        expect(() => read(bad), _badOutput);
      });
    }

    test('text that is not JSON is a bad shape', () {
      expect(() => readLyricsOutput('{oops'), _badOutput);
    });
  });
}
