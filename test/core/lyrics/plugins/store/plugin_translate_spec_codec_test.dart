import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_translate_spec.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_translate_spec_codec.dart';

void main() {
  test('a spec survives a round trip', () {
    const spec = PluginTranslateSpec(
      languages: ['vi', 'en'],
      maxLines: 20,
      maxChars: 2000,
      timeoutSec: 30,
    );
    final back = decodePluginTranslateSpec(encodePluginTranslateSpec(spec))!;
    expect(back.languages, ['vi', 'en']);
    expect(back.maxLines, 20);
    expect(back.maxChars, 2000);
    expect(back.timeoutSec, 30);
  });

  test('null, broken or invalid text decodes to null', () {
    expect(decodePluginTranslateSpec(null), isNull);
    expect(decodePluginTranslateSpec(''), isNull);
    expect(decodePluginTranslateSpec('{not json'), isNull);
    expect(decodePluginTranslateSpec('[1]'), isNull);
    expect(decodePluginTranslateSpec('"text"'), isNull);
    expect(decodePluginTranslateSpec('{"maxLines": 20}'), isNull);
    expect(decodePluginTranslateSpec('{"languages": []}'), isNull);
    expect(
      decodePluginTranslateSpec('{"languages": ["vi"], "maxLines": 1}'),
      isNull,
    );
  });
}
