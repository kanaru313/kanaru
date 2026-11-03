import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_config_parser.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_problem.dart';

Map<String, dynamic> _f(String mode, [Map<String, dynamic>? more]) => {
  'title': 'T',
  'mode': mode,
  ...?more,
};

PluginConfigField _one(Map<String, dynamic> field) =>
    parsePluginConfig({'k': field}).single;

void _bad(String name, Map<String, dynamic> field, String attr) {
  test(name, () {
    expect(
      () => parsePluginConfig({'k': field}),
      throwsA(
        isA<PluginPackageProblem>()
            .having(
              (p) => p.kind,
              'kind',
              PluginPackageProblemKind.invalidManifest,
            )
            .having((p) => p.detail, 'detail', 'config.k.$attr'),
      ),
    );
  });
}

Map<String, dynamic> _input(String format, [Map<String, dynamic>? more]) =>
    _f('input', {'format': format, ...?more});

final _opts = [
  {'value': 'a', 'title': 'A', 'subtitle': 'first'},
  {'value': 'b', 'title': 'B'},
  {'value': 'c', 'title': 'C'},
];

void main() {
  group('input', () {
    test('text keeps length bounds and placeholder', () {
      final f = _one(
        _input('text', {
          'placeholder': 'hint',
          'minLength': 2,
          'maxLength': 5,
          'default': 'abc',
          'required': true,
          'pattern': '^a+\$',
          'patternMessage': 'x',
        }),
      );
      expect(f.inputFormat, PluginInputFormat.text);
      expect(f.placeholder, 'hint');
      expect((f.minLength, f.maxLength), (2, 5));
      expect(f.defaultValue, 'abc');
      expect(f.required, isTrue);
    });

    test('format defaults to text', () {
      expect(_one(_f('input')).inputFormat, PluginInputFormat.text);
    });

    test('multiline takes rows', () {
      final f = _one(_input('multiline', {'rows': 6, 'maxLength': 100}));
      expect(f.inputFormat, PluginInputFormat.multiline);
      expect(f.rows, 6);
      expect(f.maxLength, 100);
    });

    test('number keeps min, max, step and a typed default', () {
      final f = _one(
        _input('number', {'min': -1.5, 'max': 9, 'step': 0.5, 'default': 2.5}),
      );
      expect((f.min, f.max, f.step, f.defaultValue), (-1.5, 9, 0.5, 2.5));
    });

    test('number default may be a decimal string and becomes a number', () {
      expect(_one(_input('number', {'default': '5'})).defaultValue, 5);
      expect(_one(_input('number', {'default': '-2.5'})).defaultValue, -2.5);
    });

    test('integer', () {
      final f = _one(
        _input('integer', {'min': 1, 'max': 10, 'step': 2, 'default': 4}),
      );
      expect((f.min, f.max, f.step, f.defaultValue), (1, 10, 2, 4));
    });

    test('secret has no default; an empty one is none', () {
      final f = _one(_input('secret', {'default': '', 'placeholder': 'key'}));
      expect(f.defaultValue, isNull);
      expect(f.placeholder, 'key');
    });

    test('url', () {
      final f = _one(_input('url', {'default': 'https://example.com/a'}));
      expect(f.inputFormat, PluginInputFormat.url);
      expect(f.defaultValue, 'https://example.com/a');
    });

    test('inapplicable attributes are ignored', () {
      final f = _one(_input('secret', {'min': 'x', 'rows': 99, 'step': 0}));
      expect((f.min, f.rows, f.step), (null, null, null));
    });

    _bad('unknown format', _input('date'), 'format');
    _bad('required not a bool', _f('input', {'required': 'yes'}), 'required');
    _bad(
      'placeholder over 200',
      _input('text', {'placeholder': 'x' * 201}),
      'placeholder',
    );
    _bad(
      'placeholder not a string',
      _input('text', {'placeholder': 1}),
      'placeholder',
    );
    _bad('minLength negative', _input('text', {'minLength': -1}), 'minLength');
    _bad('maxLength 0', _input('text', {'maxLength': 0}), 'maxLength');
    _bad(
      'maxLength over 2000',
      _input('text', {'maxLength': 2001}),
      'maxLength',
    );
    _bad(
      'minLength above maxLength',
      _input('text', {'minLength': 5, 'maxLength': 3}),
      'minLength',
    );
    _bad(
      'minLength not an int',
      _input('text', {'minLength': 1.5}),
      'minLength',
    );
    _bad(
      'text default of wrong type',
      _input('text', {'default': 1}),
      'default',
    );
    _bad(
      'text default too long',
      _input('text', {'default': 'x' * 2001}),
      'default',
    );
    _bad(
      'text default under minLength',
      _input('text', {'minLength': 3, 'default': 'a'}),
      'default',
    );
    _bad(
      'text default over maxLength',
      _input('text', {'maxLength': 3, 'default': 'abcd'}),
      'default',
    );
    _bad('rows 0', _input('multiline', {'rows': 0}), 'rows');
    _bad('rows 11', _input('multiline', {'rows': 11}), 'rows');
    _bad('number min not a number', _input('number', {'min': 'a'}), 'min');
    _bad(
      'number max not finite',
      _input('number', {'max': double.infinity}),
      'max',
    );
    _bad('number min above max', _input('number', {'min': 5, 'max': 1}), 'min');
    _bad('number step 0', _input('number', {'step': 0}), 'step');
    _bad('number step negative', _input('number', {'step': -1}), 'step');
    _bad(
      'number default below min',
      _input('number', {'min': 1, 'default': 0}),
      'default',
    );
    _bad(
      'number default above max',
      _input('number', {'max': 1, 'default': 2}),
      'default',
    );
    _bad('number default text', _input('number', {'default': 'x'}), 'default');
    _bad('number default bool', _input('number', {'default': true}), 'default');
    _bad(
      'number default string 1e999',
      _input('number', {'default': '1e999'}),
      'default',
    );
    _bad('integer min fractional', _input('integer', {'min': 1.5}), 'min');
    _bad('integer step 0', _input('integer', {'step': 0}), 'step');
    _bad('integer step fractional', _input('integer', {'step': 0.5}), 'step');
    _bad(
      'integer unsafe max',
      _input('integer', {'max': 9007199254740992}),
      'max',
    );
    _bad(
      'integer unsafe default',
      _input('integer', {'default': 9007199254740992}),
      'default',
    );
    _bad(
      'integer fractional default',
      _input('integer', {'default': 1.5}),
      'default',
    );
    _bad(
      'integer default as string',
      _input('integer', {'default': '5'}),
      'default',
    );
    test('secret default of any string is dropped', () {
      expect(_one(_input('secret', {'default': 'x'})).defaultValue, isNull);
    });
    _bad(
      'secret default not a string',
      _input('secret', {'default': 1}),
      'default',
    );
    _bad(
      'url default http',
      _input('url', {'default': 'http://example.com'}),
      'default',
    );
    _bad(
      'url default with userinfo',
      _input('url', {'default': 'https://u@example.com'}),
      'default',
    );
    _bad(
      'url default without host',
      _input('url', {'default': 'https://'}),
      'default',
    );

    test('integer accepts the safe limits', () {
      final f = _one(
        _input('integer', {'min': -9007199254740991, 'max': 9007199254740991}),
      );
      expect(f.max, 9007199254740991);
    });
  });

  group('select', () {
    test('single with option subtitles', () {
      final f = _one(_f('select', {'options': _opts, 'default': 'b'}));
      expect(f.selectFormat, PluginSelectFormat.single);
      expect(f.options.first.subtitle, 'first');
      expect(f.options[1].subtitle, isNull);
      expect(f.defaultValue, 'b');
    });

    test('multiple keeps bounds and a typed default', () {
      final f = _one(
        _f('select', {
          'format': 'multiple',
          'options': _opts,
          'minItems': 1,
          'maxItems': 2,
          'default': ['a', 'c'],
        }),
      );
      expect(f.selectFormat, PluginSelectFormat.multiple);
      expect((f.minItems, f.maxItems), (1, 2));
      expect(f.defaultValue, isA<List<String>>());
      expect(f.defaultValue, ['a', 'c']);
    });

    _bad(
      'unknown format',
      _f('select', {'format': 'multi', 'options': _opts}),
      'format',
    );
    _bad(
      'single default not an option',
      _f('select', {'options': _opts, 'default': 'z'}),
      'default',
    );
    _bad(
      'multiple default not a list',
      _f('select', {'format': 'multiple', 'options': _opts, 'default': 'a'}),
      'default',
    );
    _bad(
      'multiple default has a stranger',
      _f('select', {
        'format': 'multiple',
        'options': _opts,
        'default': ['z'],
      }),
      'default',
    );
    _bad(
      'multiple default repeats',
      _f('select', {
        'format': 'multiple',
        'options': _opts,
        'default': ['a', 'a'],
      }),
      'default',
    );
    _bad(
      'multiple default above maxItems',
      _f('select', {
        'format': 'multiple',
        'options': _opts,
        'maxItems': 1,
        'default': ['a', 'b'],
      }),
      'default',
    );
    _bad(
      'multiple default under minItems',
      _f('select', {
        'format': 'multiple',
        'options': _opts,
        'minItems': 2,
        'default': ['a'],
      }),
      'default',
    );
    _bad(
      'maxItems above option count',
      _f('select', {'format': 'multiple', 'options': _opts, 'maxItems': 4}),
      'maxItems',
    );
    _bad(
      'minItems above option count',
      _f('select', {'format': 'multiple', 'options': _opts, 'minItems': 4}),
      'minItems',
    );
    _bad(
      'minItems above maxItems',
      _f('select', {
        'format': 'multiple',
        'options': _opts,
        'minItems': 3,
        'maxItems': 2,
      }),
      'minItems',
    );
    _bad(
      'option subtitle over 300',
      _f('select', {
        'options': [
          {'value': 'a', 'title': 'A', 'subtitle': 'x' * 301},
        ],
      }),
      'options',
    );
    _bad(
      '51 options',
      _f('select', {
        'options': [
          for (var i = 0; i < 51; i++) {'value': 'v$i', 'title': 't'},
        ],
      }),
      'options',
    );
  });

  group('list', () {
    test('text', () {
      final f = _one(
        _f('list', {
          'placeholder': 'item',
          'minItems': 1,
          'maxItems': 3,
          'default': ['a', 'b'],
        }),
      );
      expect(f.listFormat, PluginListFormat.text);
      expect(f.placeholder, 'item');
      expect((f.minItems, f.maxItems), (1, 3));
      expect(f.defaultValue, isA<List<String>>());
    });

    test('number and integer defaults are typed lists', () {
      final n = _one(
        _f('list', {
          'format': 'number',
          'default': [1, 2.5],
        }),
      );
      expect(n.defaultValue, isA<List<num>>());
      final i = _one(
        _f('list', {
          'format': 'integer',
          'default': [1, 2],
        }),
      );
      expect(i.defaultValue, isA<List<int>>());
    });

    test('url', () {
      final f = _one(
        _f('list', {
          'format': 'url',
          'default': ['https://a.io'],
        }),
      );
      expect(f.listFormat, PluginListFormat.url);
    });

    _bad('unknown format', _f('list', {'format': 'date'}), 'format');
    _bad('default not a list', _f('list', {'default': 'a'}), 'default');
    _bad(
      'default has an empty item',
      _f('list', {
        'default': [''],
      }),
      'default',
    );
    _bad(
      'default has a long item',
      _f('list', {
        'default': ['x' * 2001],
      }),
      'default',
    );
    _bad(
      'default has 51 items',
      _f('list', {
        'default': [for (var i = 0; i < 51; i++) 'a'],
      }),
      'default',
    );
    _bad(
      'number default with text',
      _f('list', {
        'format': 'number',
        'default': ['1'],
      }),
      'default',
    );
    _bad(
      'integer default with fraction',
      _f('list', {
        'format': 'integer',
        'default': [1.5],
      }),
      'default',
    );
    _bad(
      'integer default unsafe',
      _f('list', {
        'format': 'integer',
        'default': [9007199254740992],
      }),
      'default',
    );
    _bad(
      'url default with http',
      _f('list', {
        'format': 'url',
        'default': ['http://a.io'],
      }),
      'default',
    );
    _bad(
      'default has a blank item',
      _f('list', {
        'default': ['  '],
      }),
      'default',
    );
    _bad('maxItems 51', _f('list', {'maxItems': 51}), 'maxItems');
    _bad(
      'minItems above maxItems',
      _f('list', {'minItems': 3, 'maxItems': 2}),
      'minItems',
    );
    _bad(
      'default under minItems',
      _f('list', {
        'minItems': 2,
        'default': ['a'],
      }),
      'default',
    );
  });

  group('map', () {
    test('default is a typed map', () {
      final f = _one(
        _f('map', {
          'maxItems': 5,
          'default': {'a': '1', 'b': ''},
        }),
      );
      expect(f.mode, PluginConfigMode.map);
      expect(f.maxItems, 5);
      expect(f.defaultValue, isA<Map<String, String>>());
      expect(f.defaultValue, {'a': '1', 'b': ''});
    });

    test('format text is accepted', () {
      expect(_one(_f('map', {'format': 'text'})).mode, PluginConfigMode.map);
    });

    _bad('unknown format', _f('map', {'format': 'json'}), 'format');
    _bad('maxItems 0', _f('map', {'maxItems': 0}), 'maxItems');
    _bad('maxItems 51', _f('map', {'maxItems': 51}), 'maxItems');
    _bad(
      'default not a map',
      _f('map', {
        'default': ['a'],
      }),
      'default',
    );
    _bad(
      'default value not a string',
      _f('map', {
        'default': {'a': 1},
      }),
      'default',
    );
    _bad(
      'default value over 2000',
      _f('map', {
        'default': {'a': 'x' * 2001},
      }),
      'default',
    );
    _bad(
      'default key empty',
      _f('map', {
        'default': {'': 'v'},
      }),
      'default',
    );
    _bad(
      'default key over 100',
      _f('map', {
        'default': {'k' * 101: 'v'},
      }),
      'default',
    );
    _bad(
      'default key with outer space',
      _f('map', {
        'default': {' a': 'v'},
      }),
      'default',
    );
    _bad(
      'default key with control char',
      _f('map', {
        'default': {'a\u0007': 'v'},
      }),
      'default',
    );
    _bad(
      'default key __proto__',
      _f('map', {
        'default': {'__proto__': 'v'},
      }),
      'default',
    );
    _bad(
      'default above maxItems',
      _f('map', {
        'maxItems': 1,
        'default': {'a': '1', 'b': '2'},
      }),
      'default',
    );
  });

  group('toggle and common', () {
    test('toggle with a bool default', () {
      final f = _one(_f('toggle', {'default': true, 'required': true}));
      expect(f.defaultValue, true);
      expect(f.required, isTrue);
    });

    test('required defaults to false', () {
      expect(_one(_f('toggle')).required, isFalse);
    });

    _bad('toggle with a format', _f('toggle', {'format': 'text'}), 'format');
    _bad(
      'toggle default of wrong type',
      _f('toggle', {'default': 'yes'}),
      'default',
    );
    _bad('unknown mode', _f('slider'), 'mode');
    _bad('empty title', {'title': ' ', 'mode': 'toggle'}, 'title');
    _bad(
      'subtitle over 300',
      _f('toggle', {'subtitle': 'x' * 301}),
      'subtitle',
    );
  });

  group('caps', () {
    test('20 fields pass and 21 do not', () {
      Map<String, dynamic> many(int n) => {
        for (var i = 0; i < n; i++) 'k$i': _f('toggle'),
      };
      expect(parsePluginConfig(many(20)), hasLength(20));
      expect(
        () => parsePluginConfig(many(21)),
        throwsA(
          isA<PluginPackageProblem>().having(
            (p) => p.detail,
            'detail',
            'config',
          ),
        ),
      );
    });

    test('config must be an object', () {
      expect(() => parsePluginConfig([]), throwsA(isA<PluginPackageProblem>()));
    });
  });
}
