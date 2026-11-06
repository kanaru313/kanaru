import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_config_values.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_ai_tune.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';

const _model = PluginConfigField(
  key: 'model',
  title: 'Model',
  mode: PluginConfigMode.select,
  selectFormat: PluginSelectFormat.single,
  custom: true,
  defaultValue: 'flash',
  options: [
    PluginConfigOption(value: 'flash', title: 'Flash'),
    PluginConfigOption(value: 'pro', title: 'Pro'),
  ],
);
const _style = PluginConfigField(
  key: 'style',
  title: 'Style',
  mode: PluginConfigMode.select,
  selectFormat: PluginSelectFormat.single,
  defaultValue: 'literal',
  options: [
    PluginConfigOption(value: 'literal', title: 'Literal'),
    PluginConfigOption(value: 'poetic', title: 'Poetic'),
  ],
);
const _instruction = PluginConfigField(
  key: 'customInstruction',
  title: 'Instruction',
  mode: PluginConfigMode.input,
  inputFormat: PluginInputFormat.text,
);
const _other = PluginConfigField(
  key: 'temperature',
  title: 'Temperature',
  mode: PluginConfigMode.input,
  inputFormat: PluginInputFormat.number,
);

final _tune = aiTuneOf(PluginKind.aiTranslate, const [
  _other,
  _model,
  _style,
  _instruction,
])!;

String _hash(String text) => 'sha256:${sha256.convert(utf8.encode(text))}';

void main() {
  group('aiTuneOf', () {
    test('is null for lyrics and translate plugins', () {
      const all = [_model, _style, _instruction];
      expect(aiTuneOf(PluginKind.lyrics, all), isNull);
      expect(aiTuneOf(PluginKind.translate, all), isNull);
      expect(aiTuneOf(null, all), isNull);
    });

    test('finds the three fields by key', () {
      expect(_tune.model, _model);
      expect(_tune.style, _style);
      expect(_tune.instruction, _instruction);
    });

    test('is null when a field is missing or of the wrong mode', () {
      expect(aiTuneOf(PluginKind.aiTranslate, const [_model, _style]), isNull);
      expect(
        aiTuneOf(PluginKind.aiTranslate, [
          _model,
          _style,
          const PluginConfigField(
            key: 'customInstruction',
            title: 'I',
            mode: PluginConfigMode.toggle,
          ),
        ]),
        isNull,
      );
    });
  });

  group('aiTuneValues', () {
    test('reads the defaults when nothing is stored', () {
      final v = aiTuneValues(_tune, {});
      expect(v.model, 'flash');
      expect(v.style, 'literal');
      expect(v.instruction, '');
    });

    test('reads stored values; a value that no longer fits reads null', () {
      final v = aiTuneValues(_tune, {
        'model': 'pro',
        'style': 'gone',
        'customInstruction': 'be kind',
      });
      expect(v.model, 'pro');
      expect(v.style, isNull);
      expect(v.instruction, 'be kind');
    });

    test('a model the user added is valid', () {
      final v = aiTuneValues(_tune, {
        'model': 'mine',
        'model.custom': [
          {'value': 'mine'},
        ],
      });
      expect(v.model, 'mine');
    });
  });

  group('snapshot', () {
    test('holds the effective values and a hash, never the text', () {
      final json = encodeAiSnapshot(_tune, {
        'model': 'pro',
        'customInstruction': 'A',
      }, 'B');
      expect(decodeAiSnapshot(json), {
        'model': 'pro',
        'style': 'literal',
        'instructionHash': _hash('A\nB'),
      });
      expect(json, isNot(contains('"A')));
    });

    test('an empty instruction has a null hash', () {
      expect(decodeAiSnapshot(encodeAiSnapshot(_tune, {}, null)), {
        'model': 'flash',
        'style': 'literal',
        'instructionHash': null,
      });
    });

    test('decode gives null for null, damaged and non-object text', () {
      expect(decodeAiSnapshot(null), isNull);
      expect(decodeAiSnapshot('{'), isNull);
      expect(decodeAiSnapshot('[1]'), isNull);
    });
  });

  group('aiTuneChanges', () {
    final snapshot = decodeAiSnapshot(
      encodeAiSnapshot(_tune, {'customInstruction': 'A'}, null),
    );

    List<AiTuneChange> changes(
      Map<String, Object?> stored, [
      String? note,
      Map<String, Object?>? snap,
    ]) => aiTuneChanges(_tune, snap ?? snapshot, stored, note);

    test('nothing stored and a snapshot of the defaults: no change', () {
      final fresh = decodeAiSnapshot(encodeAiSnapshot(_tune, {}, null));
      expect(changes({}, null, fresh), isEmpty);
    });

    test('no snapshot: no change', () {
      expect(aiTuneChanges(_tune, null, {'model': 'pro'}, null), isEmpty);
    });

    test('same settings: no change', () {
      expect(changes({'customInstruction': 'A'}), isEmpty);
    });

    test('a different model is a change', () {
      expect(changes({'customInstruction': 'A', 'model': 'pro'}), [
        const AiTuneChange(AiTuneKey.model, 'flash', 'pro'),
      ]);
    });

    test('a different style is a change', () {
      expect(changes({'customInstruction': 'A', 'style': 'poetic'}), [
        const AiTuneChange(AiTuneKey.style, 'literal', 'poetic'),
      ]);
    });

    test('a changed shared instruction is a change', () {
      expect(changes({'customInstruction': 'A2'}), [
        AiTuneChange(AiTuneKey.instruction, _hash('A'), _hash('A2')),
      ]);
    });

    test("the song's note is a change", () {
      expect(changes({'customInstruction': 'A'}, 'B'), [
        AiTuneChange(AiTuneKey.instruction, _hash('A'), _hash('A\nB')),
      ]);
    });

    test('a snapshot option the plugin dropped is flagged', () {
      final old = {'model': 'retired', 'style': 'literal'};
      expect(changes({}, null, old), [
        const AiTuneChange(
          AiTuneKey.model,
          'retired',
          'flash',
          removedOption: true,
        ),
      ]);
    });

    test('a key the snapshot lacks is skipped', () {
      expect(changes({'model': 'pro', 'style': 'poetic'}, 'note', {}), isEmpty);
      expect(changes({'model': 'pro'}, null, {'style': 'literal'}), isEmpty);
    });

    test('a model the user added then deleted is a removed option', () {
      final snap = {
        'model': 'mine',
        'style': 'literal',
        'instructionHash': null,
      };
      expect(changes({}, null, snap), [
        const AiTuneChange(
          AiTuneKey.model,
          'mine',
          'flash',
          removedOption: true,
        ),
      ]);
      expect(
        changes(
          {
            'model': 'mine',
            'model.custom': [
              {'value': 'mine'},
            ],
          },
          null,
          snap,
        ),
        isEmpty,
      );
    });
  });

  group('aiTuneChangesOf', () {
    final info = TranslationTargetInfo(
      hash: 'h',
      effective: translationLanguageFor('en')!,
      songOverride: null,
      defaultTarget: translationLanguageFor('en')!,
    );
    final service = TranslationServiceId.tryParse('plugin-abc123def456')!;
    TranslationReady ready({
      bool other = false,
      bool refreshing = false,
      String? settings,
    }) => TranslationReady(
      info,
      service,
      'ja',
      const [],
      other,
      refreshing: refreshing,
      settingsJson: settings,
    );
    final snap = encodeAiSnapshot(_tune, {}, null);
    final stored = {'model': 'pro'};

    test('reports for the finished version of the plugin itself', () {
      expect(
        aiTuneChangesOf(_tune, ready(settings: snap), stored, null),
        hasLength(1),
      );
    });

    test('ignores another service, a refresh and a missing snapshot', () {
      expect(
        aiTuneChangesOf(
          _tune,
          ready(other: true, settings: snap),
          stored,
          null,
        ),
        isEmpty,
      );
      expect(
        aiTuneChangesOf(
          _tune,
          ready(refreshing: true, settings: snap),
          stored,
          null,
        ),
        isEmpty,
      );
      expect(aiTuneChangesOf(_tune, ready(), stored, null), isEmpty);
    });
  });

  group('aiOptionTitle', () {
    test('gives the title of the option', () {
      expect(aiOptionTitle(_model, 'pro'), 'Pro');
    });

    test('gives null for an unknown value or null', () {
      expect(aiOptionTitle(_model, 'gone'), isNull);
      expect(aiOptionTitle(_model, null), isNull);
    });

    test('a user model has its value as title', () {
      final field = pluginEffectiveField(_model, {
        'model.custom': [
          {'value': 'mine'},
        ],
      });
      expect(aiOptionTitle(field, 'mine'), 'mine');
    });
  });
}
