import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';

void main() {
  group('PluginKind', () {
    test('fromValue parses known values and returns null for unknown', () {
      expect(PluginKind.fromValue('lyrics'), PluginKind.lyrics);
      expect(PluginKind.fromValue('translate'), PluginKind.translate);
      expect(PluginKind.fromValue('ai-translate'), PluginKind.aiTranslate);
      expect(PluginKind.fromValue('unknown'), isNull);
      expect(PluginKind.fromValue(''), isNull);
    });

    test('isTranslation is true only for translation family kinds', () {
      expect(PluginKind.lyrics.isTranslation, isFalse);
      expect(PluginKind.translate.isTranslation, isTrue);
      expect(PluginKind.aiTranslate.isTranslation, isTrue);
    });

    test('accepts matches the exact kind or any kind of the translation '
        'family', () {
      expect(PluginKind.lyrics.accepts('lyrics'), isTrue);
      expect(PluginKind.lyrics.accepts('translate'), isFalse);
      expect(PluginKind.lyrics.accepts('ai-translate'), isFalse);
      expect(PluginKind.lyrics.accepts('unknown'), isFalse);

      expect(PluginKind.translate.accepts('translate'), isTrue);
      expect(PluginKind.translate.accepts('ai-translate'), isTrue);
      expect(PluginKind.translate.accepts('lyrics'), isFalse);
      expect(PluginKind.translate.accepts('unknown'), isFalse);

      expect(PluginKind.aiTranslate.accepts('ai-translate'), isTrue);
      expect(PluginKind.aiTranslate.accepts('translate'), isTrue);
      expect(PluginKind.aiTranslate.accepts('lyrics'), isFalse);
      expect(PluginKind.aiTranslate.accepts('unknown'), isFalse);
    });
  });
}
