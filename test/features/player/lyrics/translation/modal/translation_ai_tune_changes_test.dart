import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics_translation/translation_ai_tune.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_ai_tune_changes.dart';
import 'package:kanaru/l10n/app_localizations_vi.dart';

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
    PluginConfigOption(value: 'natural', title: 'Natural'),
  ],
);
const _note = PluginConfigField(
  key: 'customInstruction',
  title: 'Instruction',
  mode: PluginConfigMode.input,
  inputFormat: PluginInputFormat.text,
);

void main() {
  final tune = aiTuneOf(PluginKind.aiTranslate, [_model, _style, _note])!;
  final vi = AppLocalizationsVi();

  test('Vietnamese and English words', () {
    expect(vi.translationAiTuneLater, 'Để sau');
    expect(
      vi.lyricsTranslationModalTranslatedByWithStyle('A', 'Tự nhiên'),
      'Dịch bởi A · Tự nhiên',
    );
  });

  test('the style of a snapshot is its option title', () {
    expect(
      aiSnapshotStyleTitle(tune, '{"model":"flash","style":"natural"}'),
      'Natural',
    );
    expect(aiSnapshotStyleTitle(tune, '{"style":"gone"}'), isNull);
    expect(aiSnapshotStyleTitle(tune, '{"model":"flash"}'), isNull);
    expect(aiSnapshotStyleTitle(tune, null), isNull);
    expect(aiSnapshotStyleTitle(tune, 'not json'), isNull);
  });
}
