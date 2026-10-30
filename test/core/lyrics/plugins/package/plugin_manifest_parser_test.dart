import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest_parser.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_problem.dart';

import 'package_test_helpers.dart';

PluginManifest parse(Map<String, dynamic> json) =>
    parsePluginManifest(utf8.encode(jsonEncode(json)));

/// Parses [json] expecting a problem of [kind] with [detail].
void expectProblem(
  Map<String, dynamic> json,
  PluginPackageProblemKind kind, [
  String? detail,
]) {
  expect(
    () => parse(json),
    throwsA(
      isA<PluginPackageProblem>()
          .having((p) => p.kind, 'kind', kind)
          .having((p) => p.detail, 'detail', detail ?? anything),
    ),
  );
}

/// A valid manifest with [change] applied to its `metadata`.
Map<String, dynamic> withMeta(void Function(Map<String, dynamic>) change) {
  final json = validManifest();
  change(json['metadata'] as Map<String, dynamic>);
  return json;
}

Map<String, dynamic> withConfig(Object config) =>
    validManifest()..['config'] = config;

void main() {
  const invalid = PluginPackageProblemKind.invalidManifest;

  test('parses a full manifest and ignores unknown fields', () {
    final json = validManifest()
      ..['future'] = 1
      ..['config'] = {
        'cookie': {'title': 'Cookie', 'mode': 'input', 'format': 'secret'},
      };
    (json['metadata'] as Map)['extra'] = true;
    final manifest = parse(json);
    expect(manifest.name, 'Demo');
    expect(manifest.version, 3);
    expect(manifest.hosts, ['music.example.com']);
    expect(manifest.searchScript, 'search.js');
    expect(manifest.config.single.inputFormat, PluginInputFormat.secret);
  });

  test('accepts a UTF-8 byte order mark', () {
    final bytes = [
      0xef,
      0xbb,
      0xbf,
      ...utf8.encode(jsonEncode(validManifest())),
    ];
    expect(parsePluginManifest(Uint8List.fromList(bytes)).name, 'Demo');
  });

  group('plugin.json shape', () {
    test('rejects invalid JSON', () {
      expect(
        () => parsePluginManifest(utf8.encode('{nope')),
        throwsA(
          isA<PluginPackageProblem>().having((p) => p.kind, 'kind', invalid),
        ),
      );
    });

    test('rejects non UTF-8 bytes', () {
      expect(
        () => parsePluginManifest(Uint8List.fromList([0xff, 0xfe, 0x7b])),
        throwsA(
          isA<PluginPackageProblem>().having((p) => p.kind, 'kind', invalid),
        ),
      );
    });

    test('rejects a JSON array', () {
      expect(
        () => parsePluginManifest(utf8.encode('[]')),
        throwsA(
          isA<PluginPackageProblem>().having((p) => p.kind, 'kind', invalid),
        ),
      );
    });

    test('rejects missing metadata and script objects', () {
      expectProblem({'script': {}}, invalid, 'metadata');
      expectProblem(validManifest()..remove('script'), invalid, 'script');
    });
  });

  group('apiVersion and type', () {
    test('apiVersion 2 needs a newer app', () {
      expectProblem(
        withMeta((m) => m['apiVersion'] = 2),
        PluginPackageProblemKind.needsNewerApp,
      );
    });

    for (final bad in [0, -1, '1', 1.0, null, true]) {
      test('apiVersion $bad is invalid', () {
        expectProblem(
          withMeta((m) => m['apiVersion'] = bad),
          invalid,
          'metadata.apiVersion',
        );
      });
    }

    test('type other than lyrics is wrongType', () {
      expectProblem(
        withMeta((m) => m['type'] = 'theme'),
        PluginPackageProblemKind.wrongType,
      );
    });
  });

  group('name, version, author, description', () {
    test('name is trimmed and stripped of control characters', () {
      final m = parse(withMeta((m) => m['name'] = '  A\u0007B\n '));
      expect(m.name, 'AB');
    });

    for (final bad in ['', '   ', '\u0001', 'x' * 81, 5, null]) {
      test(
        'rejects name ${bad.toString().length > 10 ? 'x*81' : '"$bad"'}',
        () {
          expectProblem(
            withMeta((m) => m['name'] = bad),
            invalid,
            'metadata.name',
          );
        },
      );
    }

    test('name of 80 characters is accepted', () {
      expect(parse(withMeta((m) => m['name'] = 'x' * 80)).name.length, 80);
    });

    for (final bad in [0, -3, 2147483648, 1.5, '3', null]) {
      test('rejects version $bad', () {
        expectProblem(
          withMeta((m) => m['version'] = bad),
          invalid,
          'metadata.version',
        );
      });
    }

    test('accepts version 1 and 2^31-1', () {
      expect(parse(withMeta((m) => m['version'] = 1)).version, 1);
      expect(
        parse(withMeta((m) => m['version'] = 2147483647)).version,
        2147483647,
      );
    });

    test('author and description are optional but length capped', () {
      final json = validManifest();
      (json['metadata'] as Map)
        ..remove('author')
        ..remove('description');
      final m = parse(json);
      expect(m.author, '');
      expect(m.description, '');
      expectProblem(
        withMeta((m) => m['author'] = 'a' * 81),
        invalid,
        'metadata.author',
      );
      expectProblem(
        withMeta((m) => m['description'] = 'd' * 501),
        invalid,
        'metadata.description',
      );
    });

    test('description keeps newlines', () {
      expect(
        parse(withMeta((m) => m['description'] = 'a\nb')).description,
        'a\nb',
      );
    });
  });

  group('hosts', () {
    test('lower-cases and deduplicates', () {
      final m = parse(
        withMeta(
          (m) => m['hosts'] = ['Music.Example.com', 'music.example.com '],
        ),
      );
      expect(m.hosts, ['music.example.com']);
    });

    for (final host in [
      '127.0.0.1',
      'localhost',
      'a.local',
      'http://x.com',
      'a.com:80',
    ]) {
      test('rejects host $host', () {
        expectProblem(
          withMeta((m) => m['hosts'] = ['ok.example.com', host]),
          PluginPackageProblemKind.badHost,
          host,
        );
      });
    }

    for (final bad in [
      <String>[],
      'a.com',
      [1],
      List.filled(21, 'a.com'),
    ]) {
      test('rejects hosts value of $bad', () {
        expectProblem(
          withMeta((m) => m['hosts'] = bad),
          invalid,
          'metadata.hosts',
        );
      });
    }

    test('accepts 20 hosts', () {
      final hosts = [for (var i = 0; i < 20; i++) 'h$i.example.com'];
      expect(parse(withMeta((m) => m['hosts'] = hosts)).hosts, hasLength(20));
    });
  });

  group('script', () {
    for (final bad in ['../x.js', 'a/b.js', '', 5, null]) {
      test('rejects script.search $bad', () {
        final json = validManifest();
        (json['script'] as Map)['search'] = bad;
        expectProblem(json, invalid, 'script.search');
      });
    }
  });

  group('config', () {
    test('is optional', () => expect(parse(validManifest()).config, isEmpty));

    test('parses input, select and toggle with defaults, in order', () {
      final m = parse(
        withConfig({
          'name': {'title': 'Name', 'mode': 'input', 'default': 'x'},
          'limit': {
            'title': 'Limit',
            'mode': 'input',
            'format': 'number',
            'default': 5,
          },
          'region': {
            'title': 'Region',
            'mode': 'select',
            'format': 'single',
            'options': [
              {'value': 'us', 'title': 'US'},
              {'value': 'vn', 'title': 'VN'},
            ],
            'default': 'vn',
          },
          'strict': {'title': 'Strict', 'mode': 'toggle', 'default': true},
        }),
      );
      expect(m.config.map((f) => f.key), ['name', 'limit', 'region', 'strict']);
      expect(m.config[0].inputFormat, PluginInputFormat.text);
      expect(m.config[1].defaultValue, '5');
      expect(m.config[2].options.map((o) => o.value), ['us', 'vn']);
      expect(m.config[2].defaultValue, 'vn');
      expect(m.config[3].defaultValue, true);
    });

    void bad(String name, Object config, String field) {
      test(name, () => expectProblem(withConfig(config), invalid, field));
    }

    bad('config must be an object', [], 'config');
    bad('more than 20 fields', {
      for (var i = 0; i < 21; i++) 'k$i': {'title': 't', 'mode': 'toggle'},
    }, 'config');
    bad('bad key', {
      'a-b': {'title': 't', 'mode': 'toggle'},
    }, 'config.a-b');
    bad('key over 40 chars', {
      'k' * 41: {'title': 't', 'mode': 'toggle'},
    }, 'config.${'k' * 41}');
    bad('empty title', {
      'a': {'title': ' ', 'mode': 'toggle'},
    }, 'config.a.title');
    bad('title over 80', {
      'a': {'title': 't' * 81, 'mode': 'toggle'},
    }, 'config.a.title');
    bad('unknown mode', {
      'a': {'title': 't', 'mode': 'slider'},
    }, 'config.a.mode');
    bad('unknown input format', {
      'a': {'title': 't', 'mode': 'input', 'format': 'date'},
    }, 'config.a.format');
    bad('input default of wrong type', {
      'a': {'title': 't', 'mode': 'input', 'default': true},
    }, 'config.a.default');
    bad('number default that is not a number', {
      'a': {'title': 't', 'mode': 'input', 'format': 'number', 'default': 'x'},
    }, 'config.a.default');
    bad('select without options', {
      'a': {'title': 't', 'mode': 'select'},
    }, 'config.a.options');
    bad('select with empty options', {
      'a': {'title': 't', 'mode': 'select', 'options': []},
    }, 'config.a.options');
    bad('select with 51 options', {
      'a': {
        'title': 't',
        'mode': 'select',
        'options': [
          for (var i = 0; i < 51; i++) {'value': 'v$i', 'title': 't'},
        ],
      },
    }, 'config.a.options');
    bad('option missing title', {
      'a': {
        'title': 't',
        'mode': 'select',
        'options': [
          {'value': 'v'},
        ],
      },
    }, 'config.a.options');
    bad('duplicate option values', {
      'a': {
        'title': 't',
        'mode': 'select',
        'options': [
          {'value': 'v', 'title': 'a'},
          {'value': 'v', 'title': 'b'},
        ],
      },
    }, 'config.a.options');
    bad('select format other than single', {
      'a': {
        'title': 't',
        'mode': 'select',
        'format': 'multi',
        'options': [
          {'value': 'v', 'title': 'a'},
        ],
      },
    }, 'config.a.format');
    bad('select default not among options', {
      'a': {
        'title': 't',
        'mode': 'select',
        'options': [
          {'value': 'v', 'title': 'a'},
        ],
        'default': 'z',
      },
    }, 'config.a.default');
    bad('toggle with a format', {
      'a': {'title': 't', 'mode': 'toggle', 'format': 'text'},
    }, 'config.a.format');
    bad('toggle default of wrong type', {
      'a': {'title': 't', 'mode': 'toggle', 'default': 'yes'},
    }, 'config.a.default');
  });

  group('display text', () {
    test('bidi controls and zero-width characters are removed', () {
      final m = parse(
        withMeta((m) {
          m['name'] = 'A\u202eB\u200bC\u2066D\ufeff';
          m['author'] = 'x\u2029y';
          m['description'] = 'a\u202eb\nc';
        }),
      );
      expect(m.name, 'ABCD');
      expect(m.author, 'xy');
      expect(m.description, 'ab\nc');
    });

    test('config titles are cleaned too', () {
      final m = parse(
        withConfig({
          'a': {
            'title': 'T\u202eit\u0007le',
            'mode': 'select',
            'options': [
              {'value': 'v', 'title': 'O\u200bk'},
            ],
          },
        }),
      );
      expect(m.config.single.title, 'Title');
      expect(m.config.single.options.single.title, 'Ok');
    });

    test('lengths count code points, not UTF-16 units', () {
      expect(
        parse(withMeta((m) => m['name'] = '😀' * 80)).name.runes.length,
        80,
      );
      expectProblem(
        withMeta((m) => m['name'] = '😀' * 81),
        invalid,
        'metadata.name',
      );
    });

    test('a problem detail is cut and has no control characters', () {
      final problem = PluginPackageProblem(
        PluginPackageProblemKind.unsafeEntry,
        detail: '${'a' * 300}\u0000\n',
        message: 'm' * 500,
      );
      expect(problem.detail.runes.length, 200);
      expect(
        PluginPackageProblem(
          PluginPackageProblemKind.unsafeEntry,
          detail: 'a\u0000b\u202e',
        ).detail,
        'a?b?',
      );
      expect(problem.message!.length, 200);
    });

    test('wrongType does not echo a non-string type', () {
      expectProblem(
        withMeta((m) => m['type'] = {'a': 'x' * 1000}),
        PluginPackageProblemKind.wrongType,
        '',
      );
    });

    for (final bad in ['NaN', 'Infinity', '0x10', ' 5', '1e999', '']) {
      test('number default "$bad" is refused', () {
        expectProblem(
          withConfig({
            'a': {
              'title': 't',
              'mode': 'input',
              'format': 'number',
              'default': bad,
            },
          }),
          invalid,
          'config.a.default',
        );
      });
    }

    test('number defaults accept plain decimals', () {
      for (final good in ['5', '-2.5', '1e3']) {
        final m = parse(
          withConfig({
            'a': {
              'title': 't',
              'mode': 'input',
              'format': 'number',
              'default': good,
            },
          }),
        );
        expect(m.config.single.defaultValue, good);
      }
    });
  });
}
