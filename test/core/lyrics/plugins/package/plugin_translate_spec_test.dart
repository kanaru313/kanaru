import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_translate_spec.dart';

void main() {
  Map<String, Object?> block([Map<String, Object?> extra = const {}]) => {
    'languages': ['vi', 'en'],
    ...extra,
  };

  test('missing limits get the defaults', () {
    final spec = parsePluginTranslateSpec(block()).spec;
    expect(spec.languages, ['vi', 'en']);
    expect(spec.maxLines, 50);
    expect(spec.maxChars, 4000);
    expect(spec.timeoutSec, 15);
  });

  test('unknown and repeated language codes are dropped and counted', () {
    final parsed = parsePluginTranslateSpec({
      'languages': ['vi', 'xx', 'vi', 'ja'],
    });
    expect(parsed.spec.languages, ['vi', 'ja']);
    expect(parsed.droppedLanguages, 2);
  });

  test('no usable language is refused', () {
    for (final languages in [
      <Object?>[],
      ['xx'],
      [1],
      'vi',
    ]) {
      expect(
        () => parsePluginTranslateSpec({'languages': languages}),
        throwsA(
          isA<PluginTranslateSpecError>().having(
            (e) => e.field,
            'field',
            'translate.languages',
          ),
        ),
      );
    }
  });

  test('timeout above the host cap is clamped, not refused', () {
    expect(
      parsePluginTranslateSpec(block({'timeoutSec': 200})).spec.timeoutSec,
      90,
    );
    expect(
      parsePluginTranslateSpec(block({'timeoutSec': 600})).spec.timeoutSec,
      90,
    );
  });

  test('values outside their bounds name the field', () {
    final cases = {
      'maxLines': [9, 201, '50'],
      'maxChars': [999, 20001],
      'timeoutSec': [0, 601],
    };
    cases.forEach((key, values) {
      for (final value in values) {
        expect(
          () => parsePluginTranslateSpec(block({key: value})),
          throwsA(
            isA<PluginTranslateSpecError>().having(
              (e) => e.field,
              'field',
              'translate.$key',
            ),
          ),
          reason: '$key $value',
        );
      }
    });
  });

  test('bounds are accepted at the edges', () {
    final spec = parsePluginTranslateSpec(
      block({'maxLines': 10, 'maxChars': 20000, 'timeoutSec': 1}),
    ).spec;
    expect((spec.maxLines, spec.maxChars, spec.timeoutSec), (10, 20000, 1));
  });

  test('json round trip keeps the spec', () {
    final spec = parsePluginTranslateSpec(
      block({'maxLines': 60, 'maxChars': 6000, 'timeoutSec': 60}),
    ).spec;
    final again = parsePluginTranslateSpec(spec.toJson()).spec;
    expect(again.toJson(), spec.toJson());
  });
}
