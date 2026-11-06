import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest_parser.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_problem.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_config_schema_codec.dart';

import 'package_test_helpers.dart';

Map<String, dynamic> aiManifest([
  void Function(Map<String, dynamic> config)? change,
  String type = 'ai-translate',
]) {
  final config = aiTuneConfig();
  change?.call(config);
  return {
    'metadata': {
      'apiVersion': 1,
      'type': type,
      'name': 'AI',
      'version': 1,
      'hosts': ['api.example.com'],
    },
    'script': {'translate': 'translate.js'},
    'translate': {
      'languages': ['vi', 'en'],
    },
    'config': config,
  };
}

PluginManifest parse(Map<String, dynamic> json) =>
    parsePluginManifest(utf8.encode(jsonEncode(json)));

void expectInvalid(Map<String, dynamic> json, String detail) {
  expect(
    () => parse(json),
    throwsA(
      isA<PluginPackageProblem>()
          .having(
            (p) => p.kind,
            'kind',
            PluginPackageProblemKind.invalidManifest,
          )
          .having((p) => p.detail, 'detail', detail),
    ),
  );
}

void main() {
  test('all three tune fields are accepted', () {
    final manifest = parse(aiManifest());
    expect(manifest.config.map((f) => f.key), [
      'model',
      'style',
      'customInstruction',
    ]);
  });

  for (final key in ['model', 'style', 'customInstruction']) {
    test('missing $key is refused', () {
      expectInvalid(aiManifest((c) => c.remove(key)), 'config.$key');
    });
  }

  test('model as an input is refused', () {
    expectInvalid(
      aiManifest((c) => c['model'] = {'title': 'Model', 'mode': 'input'}),
      'config.model',
    );
  });

  test('a multiple style is refused', () {
    expectInvalid(
      aiManifest((c) => (c['style'] as Map)['format'] = 'multiple'),
      'config.style',
    );
  });

  for (final key in ['model', 'style']) {
    test('$key without options is refused', () {
      expectInvalid(
        aiManifest((c) => (c[key] as Map)['options'] = []),
        'config.$key.options',
      );
    });
  }

  for (final format in ['multiline', 'secret']) {
    test('customInstruction as $format is refused', () {
      expectInvalid(
        aiManifest((c) => (c['customInstruction'] as Map)['format'] = format),
        'config.customInstruction',
      );
    });
  }

  test('customInstruction with format text is accepted', () {
    parse(
      aiManifest((c) => (c['customInstruction'] as Map)['format'] = 'text'),
    );
  });

  test('a translate plugin needs no tune field', () {
    final manifest = parse(aiManifest((c) => c.clear(), 'translate'));
    expect(manifest.kind, PluginKind.translate);
  });

  group('custom model', () {
    void custom(Map<String, dynamic> c, {bool required = true}) {
      final model = c['model'] as Map;
      model['options'] = [];
      model['custom'] = true;
      if (required) model['required'] = true;
    }

    test('custom with no options and required is accepted', () {
      final manifest = parse(aiManifest(custom));
      final model = manifest.config.first;
      expect(model.custom, isTrue);
      expect(model.options, isEmpty);
    });

    test('custom may leave options out', () {
      parse(
        aiManifest((c) {
          custom(c);
          (c['model'] as Map).remove('options');
        }),
      );
    });

    test('custom with some options is accepted', () {
      parse(
        aiManifest((c) {
          (c['model'] as Map)['custom'] = true;
          (c['model'] as Map)['required'] = true;
        }),
      );
    });

    test('custom without required is refused', () {
      expectInvalid(
        aiManifest((c) => custom(c, required: false)),
        'config.model.required',
      );
    });

    test('custom on style is refused', () {
      expectInvalid(
        aiManifest((c) => (c['style'] as Map)['custom'] = true),
        'config.style.custom',
      );
    });

    test('custom on a translate plugin is refused', () {
      expectInvalid(
        aiManifest((c) => (c['model'] as Map)['custom'] = true, 'translate'),
        'config.model.custom',
      );
    });

    test('custom on an extra field of an ai plugin is refused', () {
      expectInvalid(
        aiManifest(
          (c) => c['extra'] = {
            'title': 'Extra',
            'mode': 'select',
            'custom': true,
            'options': [],
          },
        ),
        'config.extra.custom',
      );
    });

    for (final field in {
      'input': {'mode': 'input'},
      'list': {'mode': 'list'},
      'toggle': {'mode': 'toggle'},
      'map': {'mode': 'map'},
    }.entries) {
      test('custom on a ${field.key} field is refused', () {
        expectInvalid(
          aiManifest(
            (c) =>
                c['extra'] = {'title': 'Extra', ...field.value, 'custom': true},
          ),
          'config.extra.custom',
        );
      });
    }

    test('custom on a lyrics plugin select is refused', () {
      final json = validManifest();
      json['config'] = {
        'region': {
          'title': 'Region',
          'mode': 'select',
          'custom': true,
          'options': [
            {'value': 'a', 'title': 'A'},
          ],
        },
      };
      expectInvalid(json, 'config.region.custom');
    });

    test('custom that is not a bool is refused', () {
      expectInvalid(
        aiManifest((c) => (c['model'] as Map)['custom'] = 'yes'),
        'config.model.custom',
      );
    });

    test('custom on a multiple select is refused', () {
      expectInvalid(
        aiManifest((c) {
          custom(c);
          (c['model'] as Map)['format'] = 'multiple';
        }),
        'config.model.custom',
      );
    });

    test('the schema codec keeps custom', () {
      final fields = parse(aiManifest(custom)).config;
      final back = decodePluginConfigSchema(encodePluginConfigSchema(fields));
      expect(back.first.custom, isTrue);
      expect(back.first.options, isEmpty);
      expect(back[1].custom, isFalse);
    });
  });
}
