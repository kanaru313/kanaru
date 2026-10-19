import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/app_settings.dart';
import 'package:kanaru/core/settings/settings_codec.dart';

void main() {
  test('an empty object gives defaults', () {
    final decoded = decodeSettings(<String, Object?>{});

    expect(decoded.settings, const AppSettings());
    expect(decoded.version, settingsSchemaVersion);
    expect(decoded.unknownKeys, isEmpty);
  });

  test('anything but an object gives defaults', () {
    for (final json in [null, 3, 'dark', <Object?>[]]) {
      expect(decodeSettings(json).settings, const AppSettings());
    }
  });

  test('round-trips every field', () {
    const settings = AppSettings(
      theme: ThemePreference.dark,
      languageCode: 'vi',
      titleBar: TitleBarPreference.none,
    );

    final json = encodeSettings(settings);

    expect(json['version'], settingsSchemaVersion);
    expect(decodeSettings(json).settings, settings);
  });

  test('a wrong value falls back for that key only', () {
    final decoded = decodeSettings(<String, Object?>{
      'theme': 'purple',
      'language': 'vi',
      'titleBar': 2,
    });

    expect(decoded.settings, const AppSettings(languageCode: 'vi'));
  });

  test('rejects language values that are not a language code', () {
    for (final language in ['', 'VI', 'vi_VN', '../x', 7, true]) {
      expect(
        decodeSettings(<String, Object?>{'language': language})
            .settings
            .languageCode,
        isNull,
        reason: '$language',
      );
    }
  });

  test('keeps unknown keys and writes them back', () {
    final decoded = decodeSettings(<String, Object?>{
      'theme': 'light',
      'replayGain': 'album',
    });

    expect(decoded.unknownKeys, {'replayGain': 'album'});
    expect(
      encodeSettings(decoded.settings, unknownKeys: decoded.unknownKeys),
      containsPair('replayGain', 'album'),
    );
  });

  test('known keys win over unknown keys of the same name', () {
    final json = encodeSettings(
      const AppSettings(),
      unknownKeys: {'theme': 'dark', 'version': 9},
    );

    expect(json['theme'], 'system');
    expect(json['version'], settingsSchemaVersion);
  });

  test('reads the version, ignoring invalid ones', () {
    expect(decodeSettings(<String, Object?>{'version': 2}).version, 2);
    expect(
      decodeSettings(<String, Object?>{'version': '2'}).version,
      settingsSchemaVersion,
    );
    expect(
      decodeSettings(<String, Object?>{'version': 0}).version,
      settingsSchemaVersion,
    );
  });
}
