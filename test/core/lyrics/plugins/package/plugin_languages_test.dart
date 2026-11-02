import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_languages.dart';

void main() {
  group('parsePluginLanguages', () {
    test('missing or non-list values are global', () {
      expect(parsePluginLanguages(null), isEmpty);
      expect(parsePluginLanguages('vi'), isEmpty);
      expect(parsePluginLanguages(5), isEmpty);
      expect(parsePluginLanguages({'vi': true}), isEmpty);
    });

    test('a list over 50 items is global', () {
      expect(parsePluginLanguages(List.filled(51, 'vi')), isEmpty);
    });

    test('codes are normalized to language keys', () {
      expect(parsePluginLanguages(['vi', 'zh']), ['vie', 'zho']);
      expect(parsePluginLanguages(['zh-Hant']), ['zho']);
      expect(parsePluginLanguages(['tl']), ['tl']);
    });

    test('case and region variants collapse to one key', () {
      expect(parsePluginLanguages(['VI', 'vi-VN', 'vie']), ['vie']);
    });

    test('a wildcard makes the plugin global wherever it appears', () {
      expect(parsePluginLanguages(['*', 'vi']), isEmpty);
      expect(parsePluginLanguages(['vi', '*']), isEmpty);
      expect(parsePluginLanguages([' * ']), isEmpty);
    });

    test('items that are not usable codes are skipped', () {
      expect(parsePluginLanguages([1, null, '', 'vi']), ['vie']);
      expect(parsePluginLanguages(['und', 'zxx', 'mul']), isEmpty);
      expect(parsePluginLanguages(['x-klingon', 'not a code']), isEmpty);
    });

    test('at most 20 languages are kept', () {
      final codes = [
        for (var a = 97; a < 97 + 5; a++)
          for (var b = 97; b < 97 + 5; b++)
            'q${String.fromCharCode(a)}${String.fromCharCode(b)}',
      ];
      expect(codes.length, 25);
      expect(parsePluginLanguages(codes), hasLength(20));
    });

    test('the result cannot be modified', () {
      expect(
        () => parsePluginLanguages(['vi']).add('en'),
        throwsUnsupportedError,
      );
    });
  });
}
