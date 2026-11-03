import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_config_field.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_config_required.dart';

PluginConfigField _field(
  String key,
  PluginConfigMode mode, {
  bool required = true,
}) => PluginConfigField(key: key, title: key, mode: mode, required: required);

void main() {
  test('an absent required value is missing', () {
    final f = _field('a', PluginConfigMode.input);
    expect(missingRequiredConfig([f], const {}), [f]);
  });

  test('empty string, list and map are missing', () {
    final fields = [
      _field('s', PluginConfigMode.input),
      _field('l', PluginConfigMode.list),
      _field('m', PluginConfigMode.map),
    ];
    final missing = missingRequiredConfig(fields, {
      's': '',
      'l': <String>[],
      'm': <String, String>{},
    });
    expect(missing.map((f) => f.key), ['s', 'l', 'm']);
  });

  test('a value, a number zero and a filled collection are present', () {
    final fields = [
      _field('s', PluginConfigMode.input),
      _field('n', PluginConfigMode.input),
      _field('l', PluginConfigMode.list),
    ];
    expect(
      missingRequiredConfig(fields, {
        's': 'x',
        'n': 0,
        'l': ['a'],
      }),
      isEmpty,
    );
  });

  test('a toggle is never missing', () {
    expect(
      missingRequiredConfig([_field('t', PluginConfigMode.toggle)], const {}),
      isEmpty,
    );
  });

  test('an optional field is never missing', () {
    expect(
      missingRequiredConfig([
        _field('a', PluginConfigMode.input, required: false),
      ], const {}),
      isEmpty,
    );
  });

  test('a secret of only spaces is missing, plain text is taken literally', () {
    const secret = PluginConfigField(
      key: 'k',
      title: 'k',
      mode: PluginConfigMode.input,
      inputFormat: PluginInputFormat.secret,
      required: true,
    );
    final text = _field('t', PluginConfigMode.input);
    expect(missingRequiredConfig([secret], {'k': '   '}), [secret]);
    expect(missingRequiredConfig([secret], {'k': ' x '}), isEmpty);
    expect(missingRequiredConfig([text], {'t': '  '}), isEmpty);
  });
}
