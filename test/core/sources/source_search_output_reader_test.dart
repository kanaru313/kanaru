import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/source_models.dart';
import 'package:kanaru/core/sources/source_output_reader.dart'
    show PluginOutputException;
import 'package:kanaru/core/sources/source_search_output_reader.dart';

SourceSearchPage _search(
  Object? output, {
  String? inputNext,
  List<String>? notes,
}) => readSourceSearchOutput(
  jsonEncode(output),
  inputNext: inputNext,
  notes: notes,
);

Map<String, Object?> _item([Map<String, Object?> fields = const {}]) => {
  'id': 'abc',
  'title': 'Song',
  ...fields,
};

final _invalid = throwsA(isA<PluginOutputException>());

void main() {
  group('search output', () {
    test('reads every field of a good item', () {
      final page = _search({
        'items': [
          _item({
            'artist': 'Band',
            'durationMs': 215000,
            'artworkUrl': 'https://i.ytimg.com/a.jpg',
            'webUrl': 'https://www.youtube.com/watch?v=abc',
          }),
        ],
        'next': 'token',
      });

      expect(
        page.items.single,
        const SourceItem(
          id: 'abc',
          title: 'Song',
          artist: 'Band',
          duration: Duration(milliseconds: 215000),
          artworkUrl: 'https://i.ytimg.com/a.jpg',
          webUrl: 'https://www.youtube.com/watch?v=abc',
        ),
      );
      expect(page.next, 'token');
    });

    test('a shape that is not {items, next} is invalid', () {
      for (final output in [
        null,
        [],
        'x',
        <String, Object?>{},
        {'items': 'x'},
        {'items': [], 'next': 5},
      ]) {
        expect(() => _search(output), _invalid, reason: '$output');
      }
      expect(() => readSourceSearchOutput('{'), _invalid);
    });

    test('a bad item is dropped with a note, the others stay', () {
      final notes = <String>[];
      final page = _search({
        'items': [
          'x',
          _item({'id': ''}),
          _item({'id': 'a' * 201}),
          _item({'id': 'a\u0007b'}),
          _item({'title': '  '}),
          _item({'title': 't' * 301}),
          _item({'title': 5}),
          _item({'id': 'a' * 200, 'title': 't' * 300}),
        ],
      }, notes: notes);

      expect(page.items.single.id, 'a' * 200);
      expect(notes, hasLength(7));
      expect(notes.first, startsWith('item #1: '));
      expect(notes.last, startsWith('item #7: '));
    });

    test('an id of exactly "." or ".." is dropped with a note', () {
      final notes = <String>[];
      final page = _search({
        'items': [
          _item({'id': '.'}),
          _item({'id': '..'}),
          _item({'id': '...'}),
          _item({'id': '.a'}),
        ],
      }, notes: notes);

      expect(page.items.map((i) => i.id), ['...', '.a']);
      expect(notes, hasLength(2));
      expect(notes[0], startsWith('item #1: "id"'));
      expect(notes[1], startsWith('item #2: "id"'));
    });

    test('the title and artist are cleaned', () {
      final item = _search({
        'items': [
          _item({'title': ' \u202eSo\u200bng ', 'artist': '\u0000Band '}),
        ],
      }).items.single;

      expect(item.title, 'Song');
      expect(item.artist, 'Band');
    });

    test('an artist that is empty, too long or not a string is none', () {
      for (final artist in ['', ' ', 'a' * 201, 5]) {
        final item = _search({
          'items': [
            _item({'artist': artist}),
          ],
        }).items.single;
        expect(item.artist, isNull, reason: '$artist');
      }
      final kept = _search({
        'items': [
          _item({'artist': 'a' * 200}),
        ],
      }).items.single;
      expect(kept.artist, 'a' * 200);
    });

    test('durationMs 0, negative, over 24 h or not whole is unknown', () {
      for (final ms in [0, -1, 86400001, 1.5, 'x', true]) {
        final item = _search({
          'items': [
            _item({'durationMs': ms}),
          ],
        }).items.single;
        expect(item.duration, isNull, reason: '$ms');
      }
      final items = _search({
        'items': [
          _item({'durationMs': 1}),
          _item({'durationMs': 86400000}),
          _item({'durationMs': 180000.0}),
        ],
      }).items;
      expect(items.map((i) => i.duration?.inMilliseconds), [
        1,
        86400000,
        180000,
      ]);
    });

    test('links are kept only as absolute https without user info', () {
      for (final url in [
        'http://i.ytimg.com/a.jpg',
        '/a.jpg',
        'https://user@i.ytimg.com/a.jpg',
        'https:///a.jpg',
        'https://i.ytimg.com/${'a' * 2000}',
        5,
      ]) {
        final item = _search({
          'items': [
            _item({'artworkUrl': url, 'webUrl': url}),
          ],
        }).items.single;
        expect(item.artworkUrl, isNull, reason: '$url');
        expect(item.webUrl, isNull, reason: '$url');
      }
    });

    test('at most 200 items are kept', () {
      final notes = <String>[];
      final page = _search({
        'items': [
          for (var i = 0; i < 205; i++) _item({'id': 'id$i'}),
        ],
      }, notes: notes);

      expect(page.items, hasLength(maxSourceItems));
      expect(page.items.last.id, 'id199');
      expect(notes.single, contains('5 items over the limit'));
    });

    test('a next equal to the one sent is dropped', () {
      expect(
        _search({'items': [], 'next': 'p2'}, inputNext: 'p2').next,
        isNull,
      );
      expect(_search({'items': [], 'next': 'p3'}, inputNext: 'p2').next, 'p3');
    });

    test('an empty page with a next is allowed', () {
      final page = _search({'items': [], 'next': 'p2'});

      expect(page.items, isEmpty);
      expect(page.next, 'p2');
    });

    test('a next over 8 KiB or empty reads as none', () {
      final notes = <String>[];
      expect(
        _search({'items': [], 'next': 'a' * 8193}, notes: notes).next,
        isNull,
      );
      expect(notes, hasLength(1));
      expect(_search({'items': [], 'next': 'a' * 8192}).next, hasLength(8192));
      expect(_search({'items': [], 'next': ''}).next, isNull);
      expect(_search({'items': []}).next, isNull);
    });
  });
}
