import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_config_schema_codec.dart';

const _opts = [
  PluginConfigOption(value: 'a', title: 'A', subtitle: 'first'),
  PluginConfigOption(value: 'b', title: 'B'),
];

const _all = <PluginConfigField>[
  PluginConfigField(
    key: 'text',
    title: 'Text',
    mode: PluginConfigMode.input,
    subtitle: 'help',
    required: true,
    inputFormat: PluginInputFormat.text,
    placeholder: 'hint',
    minLength: 1,
    maxLength: 9,
    defaultValue: 'abc',
  ),
  PluginConfigField(
    key: 'multi',
    title: 'Multi',
    mode: PluginConfigMode.input,
    inputFormat: PluginInputFormat.multiline,
    rows: 5,
    minLength: 0,
    maxLength: 99,
    defaultValue: 'a\nb',
  ),
  PluginConfigField(
    key: 'num',
    title: 'Num',
    mode: PluginConfigMode.input,
    inputFormat: PluginInputFormat.number,
    min: -1.5,
    max: 9.5,
    step: 0.5,
    defaultValue: 2.5,
  ),
  PluginConfigField(
    key: 'int',
    title: 'Int',
    mode: PluginConfigMode.input,
    inputFormat: PluginInputFormat.integer,
    min: 1,
    max: 10,
    step: 2,
    defaultValue: 4,
  ),
  PluginConfigField(
    key: 'secret',
    title: 'Secret',
    mode: PluginConfigMode.input,
    inputFormat: PluginInputFormat.secret,
    placeholder: 'key',
  ),
  PluginConfigField(
    key: 'url',
    title: 'Url',
    mode: PluginConfigMode.input,
    inputFormat: PluginInputFormat.url,
    placeholder: 'https://',
    defaultValue: 'https://example.com',
  ),
  PluginConfigField(
    key: 'one',
    title: 'One',
    mode: PluginConfigMode.select,
    selectFormat: PluginSelectFormat.single,
    options: _opts,
    defaultValue: 'b',
  ),
  PluginConfigField(
    key: 'many',
    title: 'Many',
    mode: PluginConfigMode.select,
    selectFormat: PluginSelectFormat.multiple,
    options: _opts,
    minItems: 1,
    maxItems: 2,
    defaultValue: <String>['a'],
  ),
  PluginConfigField(
    key: 'flag',
    title: 'Flag',
    mode: PluginConfigMode.toggle,
    defaultValue: true,
  ),
  PluginConfigField(
    key: 'texts',
    title: 'Texts',
    mode: PluginConfigMode.list,
    listFormat: PluginListFormat.text,
    placeholder: 'item',
    minItems: 1,
    maxItems: 4,
    defaultValue: <String>['x', 'y'],
  ),
  PluginConfigField(
    key: 'nums',
    title: 'Nums',
    mode: PluginConfigMode.list,
    listFormat: PluginListFormat.number,
    defaultValue: <num>[1, 2.5],
  ),
  PluginConfigField(
    key: 'ints',
    title: 'Ints',
    mode: PluginConfigMode.list,
    listFormat: PluginListFormat.integer,
    defaultValue: <int>[1, 2],
  ),
  PluginConfigField(
    key: 'urls',
    title: 'Urls',
    mode: PluginConfigMode.list,
    listFormat: PluginListFormat.url,
    defaultValue: <String>['https://a.io'],
  ),
  PluginConfigField(
    key: 'pairs',
    title: 'Pairs',
    mode: PluginConfigMode.map,
    maxItems: 5,
    defaultValue: <String, String>{'k': 'v'},
  ),
];

void _expectSame(PluginConfigField a, PluginConfigField b) {
  expect(b.key, a.key);
  expect(b.title, a.title);
  expect(b.mode, a.mode);
  expect(b.subtitle, a.subtitle);
  expect(b.required, a.required);
  expect(b.formatName, a.formatName);
  expect(
    b.options.map((o) => (o.value, o.title, o.subtitle)),
    a.options.map((o) => (o.value, o.title, o.subtitle)),
  );
  expect(b.placeholder, a.placeholder);
  expect(
    (b.minLength, b.maxLength, b.rows),
    (a.minLength, a.maxLength, a.rows),
  );
  expect((b.min, b.max, b.step), (a.min, a.max, a.step));
  expect((b.minItems, b.maxItems), (a.minItems, a.maxItems));
  expect(b.defaultValue, a.defaultValue);
}

void main() {
  test('every mode and format round trips unchanged', () {
    final back = decodePluginConfigSchema(encodePluginConfigSchema(_all));
    expect(back, hasLength(_all.length));
    for (var i = 0; i < _all.length; i++) {
      _expectSame(_all[i], back[i]);
    }
  });

  test('typed defaults keep their types after decoding', () {
    final back = decodePluginConfigSchema(encodePluginConfigSchema(_all));
    Object? d(String key) => back.firstWhere((f) => f.key == key).defaultValue;
    expect(d('many'), isA<List<String>>());
    expect(d('nums'), isA<List<num>>());
    expect(d('ints'), isA<List<int>>());
    expect(d('pairs'), isA<Map<String, String>>());
  });

  test('required is written only when true', () {
    final json = pluginConfigToJson(_all);
    expect((json['text']! as Map)['required'], true);
    expect((json['multi']! as Map).containsKey('required'), isFalse);
    expect((json['flag']! as Map).containsKey('format'), isFalse);
  });

  group('forms the previous encoder wrote', () {
    List<PluginConfigField> decode(Map<String, Object?> json) =>
        decodePluginConfigSchema(jsonEncode(json));

    test('number with a text default decodes to a number', () {
      final f = decode({
        'n': {
          'title': 'N',
          'mode': 'input',
          'format': 'number',
          'default': '5',
        },
      }).single;
      expect(f.inputFormat, PluginInputFormat.number);
      expect(f.defaultValue, 5);
    });

    test('secret with an empty default has none', () {
      final f = decode({
        's': {'title': 'S', 'mode': 'input', 'format': 'secret', 'default': ''},
      }).single;
      expect(f.defaultValue, isNull);
      expect(isSecretField(f), isTrue);
    });

    test('select without a format is single, with option titles', () {
      final f = decode({
        'r': {
          'title': 'R',
          'mode': 'select',
          'subtitle': 'pick',
          'options': [
            {'value': 'a', 'title': 'A'},
          ],
          'default': 'a',
        },
      }).single;
      expect(f.selectFormat, PluginSelectFormat.single);
      expect(f.subtitle, 'pick');
      expect(f.defaultValue, 'a');
    });

    test('secret with a non-empty default has none', () {
      final f = decode({
        's': {
          'title': 'S',
          'mode': 'input',
          'format': 'secret',
          'default': 'abc',
        },
      }).single;
      expect(f.defaultValue, isNull);
    });

    test('toggle and text', () {
      final fields = decode({
        't': {'title': 'T', 'mode': 'toggle', 'default': false},
        'x': {'title': 'X', 'mode': 'input', 'format': 'text', 'default': 'd'},
      });
      expect(fields[0].defaultValue, false);
      expect(fields[1].defaultValue, 'd');
    });
  });

  test('unreadable text gives an empty form', () {
    expect(decodePluginConfigSchema('not json'), isEmpty);
    expect(
      decodePluginConfigSchema('{"a":{"title":"A","mode":"color"}}'),
      isEmpty,
    );
  });

  test('a source manifest is written with search and stream scripts', () {
    final json = jsonDecode(
      pluginManifestJson(
        kind: PluginKind.source,
        apiVersion: 1,
        name: 'YouTube',
        version: 2,
        hosts: const ['www.youtube.com', '*.googlevideo.com'],
        author: '',
        description: '',
        searchScript: 'search.js',
        streamScript: 'stream.js',
        config: const [],
      ),
    ) as Map<String, dynamic>;
    expect(json['metadata']['type'], 'source');
    expect(json['metadata']['hosts'], ['www.youtube.com', '*.googlevideo.com']);
    expect(json['script'], {'search': 'search.js', 'stream': 'stream.js'});
  });

  test('a lyrics manifest writes no stream script', () {
    final json = jsonDecode(
      pluginManifestJson(
        kind: PluginKind.lyrics,
        apiVersion: 1,
        name: 'Demo',
        version: 1,
        hosts: const ['api.example.com'],
        author: '',
        description: '',
        searchScript: 'search.js',
        lyricsScript: 'lyrics.js',
        config: const [],
      ),
    ) as Map<String, dynamic>;
    expect(json['script'], {'search': 'search.js', 'lyrics': 'lyrics.js'});
  });
}
