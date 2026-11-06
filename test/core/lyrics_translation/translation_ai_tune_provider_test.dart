import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_config_values_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_ai_tune_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';

import 'fake_plugin_runner.dart';

const _model = PluginConfigField(
  key: 'model',
  title: 'Model',
  mode: PluginConfigMode.select,
  selectFormat: PluginSelectFormat.single,
  custom: true,
  defaultValue: 'flash',
  options: [PluginConfigOption(value: 'flash', title: 'Flash')],
);
const _style = PluginConfigField(
  key: 'style',
  title: 'Style',
  mode: PluginConfigMode.select,
  selectFormat: PluginSelectFormat.single,
  defaultValue: 'literal',
  options: [PluginConfigOption(value: 'literal', title: 'Literal')],
);
const _note = PluginConfigField(
  key: 'customInstruction',
  title: 'Instruction',
  mode: PluginConfigMode.input,
  inputFormat: PluginInputFormat.text,
);
const _thinking = PluginConfigField(
  key: 'thinking',
  title: 'Thinking',
  mode: PluginConfigMode.toggle,
);

const _ai = 'plugin-aaaaaaaaaaaa';
const _plain = 'plugin-bbbbbbbbbbbb';
final _aiId = TranslationServiceId.tryParse(_ai)!;

ProviderContainer _container(
  List<LyricsPluginRecord> records, {
  Map<String, Object?> stored = const {},
}) {
  final container = ProviderContainer(
    overrides: [
      lyricsPluginRecordsProvider.overrideWithValue(records),
      pluginStoredConfigProvider.overrideWith(
        (ref, id) => Stream.value(stored),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('translationAiTunesProvider', () {
    test('an ai-translate plugin with the three fields has a tune', () {
      final tunes = _container([
        translateRecord(
          _ai,
          kind: PluginKind.aiTranslate,
          config: [_model, _style, _note, _thinking],
        ),
      ]).read(translationAiTunesProvider);
      expect(tunes.keys, [_aiId]);
      expect(tunes[_aiId]!.model.key, 'model');
    });

    test('a translate plugin has none, even with the same fields', () {
      final tunes = _container([
        translateRecord(_plain, config: [_model, _style, _note]),
      ]).read(translationAiTunesProvider);
      expect(tunes, isEmpty);
    });

    test('an ai-translate plugin missing a field has none', () {
      final tunes = _container([
        translateRecord(
          _ai,
          kind: PluginKind.aiTranslate,
          config: [_model, _style],
        ),
      ]).read(translationAiTunesProvider);
      expect(tunes, isEmpty);
    });

    test('a removed plugin has none', () {
      final tunes = _container([
        translateRecord(
          _ai,
          kind: PluginKind.aiTranslate,
          removed: true,
          config: [_model, _style, _note],
        ),
      ]).read(translationAiTunesProvider);
      expect(tunes, isEmpty);
    });

    test('an updated record gives the new tune', () {
      Map<TranslationServiceId, Object?> tunesOf(PluginConfigField style) =>
          _container([
            translateRecord(
              _ai,
              kind: PluginKind.aiTranslate,
              config: [_model, style, _note],
            ),
          ]).read(translationAiTunesProvider);
      final before = tunesOf(_style);
      final after = tunesOf(
        const PluginConfigField(
          key: 'style',
          title: 'Style',
          mode: PluginConfigMode.select,
          selectFormat: PluginSelectFormat.single,
          defaultValue: 'poetic',
          options: [PluginConfigOption(value: 'poetic', title: 'Poetic')],
        ),
      );
      expect(before[_aiId], isNot(after[_aiId]));
    });
  });

  group('aiTuneValuesProvider', () {
    final records = [
      translateRecord(
        _ai,
        kind: PluginKind.aiTranslate,
        config: [_model, _style, _note, _thinking],
      ),
    ];

    Future<AiTuneStored> read(Map<String, Object?> stored) async {
      final container = _container(records, stored: stored);
      container.listen(aiTuneValuesProvider(_aiId), (_, _) {});
      await container.read(pluginStoredConfigProvider(_ai).future);
      return container.read(aiTuneValuesProvider(_aiId)).requireValue;
    }

    test('keeps only the tune keys and the user\'s models', () async {
      final data = await read({
        'model': 'pro',
        'style': 'literal',
        'customInstruction': 'Keep it short',
        'model.custom': [
          {'value': 'pro'},
        ],
        'thinking': true,
        'apiKey': 'secret',
      });
      expect(data.stored.keys.toSet(), {
        'model',
        'style',
        'customInstruction',
        'model.custom',
      });
    });

    test('with nothing stored the values are the defaults', () async {
      final data = await read({});
      expect(data.stored, isEmpty);
      expect(data.values.model, 'flash');
      expect(data.values.style, 'literal');
      expect(data.values.instruction, '');
    });

    test('a service without a tune is an error', () {
      final container = _container([translateRecord(_plain)]);
      final value = container.read(
        aiTuneValuesProvider(TranslationServiceId.tryParse(_plain)!),
      );
      expect(value.hasError, isTrue);
    });
  });
}
