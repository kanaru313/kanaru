import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_config_values_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_ai_tune_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope_providers.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import '../player/fake_audio_backend.dart';
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

  group('scopedAiTuneValuesProvider', () {
    final records = [
      translateRecord(
        _ai,
        kind: PluginKind.aiTranslate,
        config: [
          _model.withOptions(const [
            PluginConfigOption(value: 'flash', title: 'Flash'),
            PluginConfigOption(value: 'pro', title: 'Pro'),
          ]),
          _style.withOptions(const [
            PluginConfigOption(value: 'literal', title: 'Literal'),
            PluginConfigOption(value: 'poetic', title: 'Poetic'),
          ]),
          _note,
        ],
      ),
    ];

    SongTranslationOverride song(
      Map<String, String> tune, {
      String? service,
    }) => SongTranslationOverride(
      hash: 'h',
      service: service ?? _ai,
      tuneJson:
          '{${tune.entries.map((e) => '"${e.key}":"${e.value}"').join(',')}}',
      chosenAt: 10,
    );

    ProviderContainer make({
      SongTranslationOverride? override,
      Map<String, Object?> stored = const {},
      int? allChosenAt,
    }) {
      final container = ProviderContainer(
        overrides: [
          audioBackendProvider.overrideWithValue(FakeAudioBackend()),
          initialSettingsProvider.overrideWithValue(
            AppSettings(
              translation: TranslationPrefs(
                show: true,
                service: _aiId,
                noticeAcknowledged: {_aiId},
                allChosenAt: allChosenAt,
              ),
            ),
          ),
          ...translatePluginOverrides(records: records),
          pluginStoredConfigProvider.overrideWith(
            (ref, id) => Stream.value(stored),
          ),
          songTranslationOverridesProvider.overrideWith(
            (ref) => Stream.value({?override?.hash: ?override}),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<AiTuneStored> read(ProviderContainer container) async {
      final provider = scopedAiTuneValuesProvider((_aiId, 'h'));
      container.listen(provider, (_, _) {});
      await container.read(songTranslationOverridesProvider.future);
      await container.read(pluginStoredConfigProvider(_ai).future);
      return container.read(provider).requireValue;
    }

    test('without an own choice it is the stored config', () async {
      final data = await read(make(stored: {'style': 'poetic'}));
      expect(data.values.style, 'poetic');
      expect(data.values.model, 'flash');
    });

    test('a song choice of this plugin overlays model and style', () async {
      final data = await read(
        make(
          override: song({'model': 'pro', 'style': 'poetic'}),
          stored: {'style': 'literal'},
        ),
      );
      expect(data.values.model, 'pro');
      expect(data.values.style, 'poetic');
    });

    test('a value the plugin no longer offers is left out', () async {
      final data = await read(
        make(
          override: song({'model': 'gone', 'style': 'poetic'}),
          stored: {'model': 'pro'},
        ),
      );
      expect(data.values.model, 'pro');
      expect(data.values.style, 'poetic');
    });

    test('a user-added model fits', () async {
      final data = await read(
        make(
          override: song({'model': 'mine'}),
          stored: {
            'model.custom': [
              {'value': 'mine'},
            ],
          },
        ),
      );
      expect(data.values.model, 'mine');
    });

    test('a choice of another plugin leaves the stored config', () async {
      final data = await read(
        make(
          override: song({'model': 'pro'}, service: _plain),
          stored: {'model': 'flash'},
        ),
      );
      expect(data.values.model, 'flash');
    });

    test('the default winning leaves the stored config', () async {
      // The default is newer than the song's choice.
      final data = await read(
        make(
          override: song({'model': 'pro'}),
          stored: {'model': 'flash'},
          allChosenAt: 99,
        ),
      );
      expect(data.values.model, 'flash');
    });
  });
}
