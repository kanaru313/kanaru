import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_output_reader.dart';
import 'package:kanaru/core/lyrics/plugins/translate/plugin_translate_output.dart';

String _json(List<Object?> items) => jsonEncode(items);

Map<String, Object?> _item(String text, [Object? detected]) => {
  'text': text,
  'detected': ?detected,
};

List<PluginTranslatedLine> _read(
  String json,
  List<String> sources, {
  String target = 'vi',
  List<String>? notes,
}) => readTranslateOutput(json, sources, target, notes ?? []);

Matcher get _rejects => throwsA(isA<PluginOutputException>());

void main() {
  test('one object per line is read in order', () {
    final lines = _read(_json([_item('a', 'en'), _item('b')]), ['x', 'y']);
    expect(lines, [(text: 'a', detected: 'en'), (text: 'b', detected: null)]);
  });

  test('a wrong length, a non-list and invalid JSON are rejected', () {
    expect(() => _read(_json([_item('a')]), ['x', 'y']), _rejects);
    expect(() => _read('{"text":"a"}', ['x']), _rejects);
    expect(() => _read('not json', ['x']), _rejects);
  });

  test('text that is not a string is rejected', () {
    expect(
      () => _read(
        _json([
          {'text': 1},
        ]),
        ['x'],
      ),
      _rejects,
    );
    expect(() => _read(_json(['a']), ['x']), _rejects);
    expect(() => _read(_json([{}]), ['x']), _rejects);
  });

  test('a bad detected becomes null and is noted', () {
    final notes = <String>[];
    final lines = _read(_json([_item('a', 'english!'), _item('b', 5)]), [
      'x',
      'y',
    ], notes: notes);
    expect(lines.map((l) => l.detected), [null, null]);
    expect(notes, ['detected']);
  });

  test('a regional or script tag is kept as given', () {
    final lines = _read(
      _json([_item('a', 'zh'), _item('b', 'zh-Hant-TW'), _item('c', 'pt-BR')]),
      ['x', 'y', 'z'],
      target: 'en',
    );
    expect(lines.map((l) => l.detected), ['zh', 'zh-Hant-TW', 'pt-BR']);
  });

  test('one empty text is fine, more than half empty is not', () {
    expect(
      _read(_json([_item(''), _item('b'), _item('c')]), ['x', 'y', 'z']),
      hasLength(3),
    );
    expect(
      () => _read(_json([_item(''), _item(''), _item('c')]), ['x', 'y', 'z']),
      _rejects,
    );
  });

  test('blank source lines do not count as empty answers', () {
    final lines = _read(_json([_item(''), _item(''), _item('c')]), [
      '',
      ' ',
      'z',
    ]);
    expect(lines, hasLength(3));
  });

  test('controls and bidi characters are removed, newlines become a space', () {
    final lines = _read(
      _json([_item('a\u0000b\u202Ec\u2067d\u0085e\nf\r\ng')]),
      ['x'],
    );
    expect(lines.single.text, 'abcd e f g');
  });

  test('tabs and NEL become a space, not nothing', () {
    final lines = _read(_json([_item('a\tb\u0085c')]), ['x']);
    expect(lines.single.text, 'a b c');
  });

  test('a line over 4 x source + 200 characters is rejected', () {
    expect(() => _read(_json([_item('a' * 205)]), ['x']), _rejects);
    expect(_read(_json([_item('a' * 204)]), ['x']), hasLength(1));
  });

  test('detected naming the target on changed text is dropped', () {
    final notes = <String>[];
    final lines = _read(_json([_item('xin chao', 'vi')]), [
      'hello',
    ], notes: notes);
    expect(lines.single.detected, isNull);
    expect(notes, ['detected']);
  });

  test('detected naming the target on unchanged text is kept', () {
    final lines = _read(_json([_item('xin chao', 'vi-VN')]), ['xin chao']);
    expect(lines.single.detected, 'vi-VN');
  });
}
