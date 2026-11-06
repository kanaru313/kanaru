import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics_translation/translation_ai_tune.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_ai_tune_changes.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
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
  final en = AppLocalizationsEn();
  final vi = AppLocalizationsVi();

  String text(
    List<AiTuneChange> changes, {
    Map<String, Object?> stored = const {},
    AppLocalizationsEn? l10n,
  }) => aiTuneChangesText(l10n ?? en, tune, stored, changes);

  test('a model change reads old to new by title', () {
    expect(
      text(const [AiTuneChange(AiTuneKey.model, 'flash', 'pro')]),
      'Flash → Pro',
    );
  });

  test('a style change reads old to new by title', () {
    expect(
      text(const [AiTuneChange(AiTuneKey.style, 'literal', 'natural')]),
      'Literal → Natural',
    );
  });

  test('a note change has its own words', () {
    expect(
      text(const [AiTuneChange(AiTuneKey.instruction, null, 'sha256:x')]),
      'Changed the note',
    );
  });

  test('a dropped option reads as no longer supported', () {
    expect(
      text(const [
        AiTuneChange(AiTuneKey.style, 'gone', 'literal', removedOption: true),
      ]),
      'gone (no longer supported) → Literal',
    );
  });

  test('a model the user added reads by its own value', () {
    expect(
      text(
        const [AiTuneChange(AiTuneKey.model, 'flash', 'mine')],
        stored: {
          'model.custom': [
            {'value': 'mine'},
          ],
        },
      ),
      'Flash → mine',
    );
  });

  test('several changes are joined with a dot', () {
    expect(
      text(const [
        AiTuneChange(AiTuneKey.model, 'flash', 'pro'),
        AiTuneChange(AiTuneKey.style, 'literal', 'natural'),
        AiTuneChange(AiTuneKey.instruction, 'sha256:a', null),
      ]),
      'Flash → Pro · Literal → Natural · Changed the note',
    );
  });

  test('Vietnamese words', () {
    expect(
      aiTuneChangesText(vi, tune, const {}, const [
        AiTuneChange(AiTuneKey.model, 'flash', 'pro'),
        AiTuneChange(AiTuneKey.style, 'gone', 'literal', removedOption: true),
        AiTuneChange(AiTuneKey.instruction, null, 'sha256:x'),
      ]),
      'Flash → Pro · gone (không còn hỗ trợ) → Literal · Đổi lời dặn',
    );
    expect(vi.translationAiTuneChanged('X'), 'Khác bản đang hiện: X');
    expect(
      en.translationAiTuneChanged('X'),
      'Differs from the version shown: X',
    );
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
