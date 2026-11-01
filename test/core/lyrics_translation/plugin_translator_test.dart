import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_translate_spec.dart';
import 'package:kanaru/core/lyrics/plugins/translate/plugin_translate_gate.dart'
    show TranslationSuperseded;
import 'package:kanaru/core/lyrics_translation/plugin_translator.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_job_work.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/lyrics_translation/translation_lines.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/lyrics_translation/translation_song_context.dart';

import 'fake_plugin_runner.dart';

final _id = TranslationServiceId.tryParse('plugin-abc123def456')!;
final _vi = translationLanguageFor('vi')!;
final _de = translationLanguageFor('de')!;

void main() {
  late FakePluginRunner runner;
  var allowed = true;

  PluginTranslator make({
    PluginTranslateSpec? spec,
    List<String> jobLines = const ['a', 'b'],
  }) => PluginTranslator(
    service: _id,
    runner: runner,
    spec: spec ?? runner.spec_,
    jobLines: jobLines,
    allowed: () => allowed,
    stillWanted: () => true,
  );

  setUp(() {
    runner = FakePluginRunner();
    allowed = true;
  });

  test('supports the languages of the spec only', () {
    final t = make(spec: const PluginTranslateSpec(languages: ['vi']));
    expect(t.supports(_vi), isTrue);
    expect(t.supports(_de), isFalse);
  });

  test('chunk limits come from the spec, capped by the job limits', () {
    final small = make(
      spec: const PluginTranslateSpec(
        languages: ['vi'],
        maxLines: 20,
        maxChars: 1500,
      ),
    ).chunkLimits;
    expect((small.maxLines, small.maxChars), (20, 1500));
    expect(small.maxChunks, maxPluginChunksPerJob);

    final big = make(
      spec: const PluginTranslateSpec(
        languages: ['vi'],
        maxLines: 5000,
        maxChars: 90000,
      ),
    ).chunkLimits;
    expect(
      (big.maxLines, big.maxChars),
      (maxTranslatedLines, maxTranslatedChars),
    );
  });

  test('more chunks than allowed: tooLong, nothing sent', () {
    final t = make(
      spec: const PluginTranslateSpec(languages: ['vi'], maxLines: 10),
    );
    final lines = [for (var i = 0; i < 10 * 21; i++) 'l$i'];
    expect(
      () => checkJobLimits(lines, _vi, t),
      throwsA(
        isA<TranslationException>().having(
          (e) => e.kind,
          'kind',
          TranslationFailureKind.tooLong,
        ),
      ),
    );
    checkJobLimits(lines.take(200).toList(), _vi, t);
    expect(runner.calls, isEmpty);
  });

  test('sends the job lyrics once as context with the song fields', () async {
    final t = make(jobLines: ['one', 'two']);
    const song = TranslationSongContext(title: 'T', artist: 'A');
    final result = await t.translate(['one'], _vi, song: song);
    await t.translate(['two'], _vi, song: song);

    expect(result.texts, ['tr:one']);
    expect(result.detected, ['ja']);
    expect(runner.songs.first!.title, 'T');
    expect(runner.songs.first!.artist, 'A');
    expect(runner.songs.first!.lyrics, 'one\ntwo');
    expect(runner.songs.last, same(runner.songs.first));
  });

  test(
    'allowed is read live: turned off between chunks sends nothing',
    () async {
      final t = make(
        spec: const PluginTranslateSpec(languages: ['vi'], maxLines: 10),
      );
      final lines = [for (var i = 0; i < 25; i++) 'line $i'];
      final partial = JobPartial();
      runner.onSend = (_) => allowed = false;

      await expectLater(
        translateMissingLines(t, lines, _vi, partial),
        throwsA(isA<TranslationSuperseded>()),
      );
      expect(runner.calls, hasLength(1));
      expect(partial.texts, hasLength(10));
    },
  );
}
