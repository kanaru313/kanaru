import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_config_values.dart';
import 'package:kanaru/shared/lyrics_plugins/config/plugin_config_value_messages.dart';

import 'lyrics_sources_harness.dart';

void main() {
  const number = PluginConfigField(
    key: 'k',
    title: 'K',
    mode: PluginConfigMode.input,
    inputFormat: PluginInputFormat.number,
    min: 0.5,
    max: 20,
  );
  const text = PluginConfigField(
    key: 'k',
    title: 'K',
    mode: PluginConfigMode.input,
    minLength: 3,
    maxLength: 9,
  );

  test('limits come from the field', () {
    String msg(PluginConfigField f, PluginValueProblem p) =>
        pluginValueProblemMessage(en, f, p);
    expect(
      msg(number, PluginValueProblem.belowMin),
      en.pluginConfigBelowMin('0.5'),
    );
    expect(
      msg(number, PluginValueProblem.aboveMax),
      en.pluginConfigAboveMax('20'),
    );
    expect(msg(text, PluginValueProblem.tooShort), en.pluginConfigTooShort(3));
    expect(msg(text, PluginValueProblem.tooLong), en.pluginConfigTooLong(9));
    expect(
      msg(number, PluginValueProblem.wrongType),
      en.pluginConfigNumberInvalid,
    );
  });

  test('every problem has a message and no limit prints as null', () {
    for (final problem in PluginValueProblem.values) {
      final message = pluginValueProblemMessage(en, text, problem);
      expect(message, isNotEmpty, reason: '$problem');
      expect(message, isNot(contains('null')), reason: '$problem');
    }
  });

  test('a whole number has no decimal point', () {
    expect(pluginNumberText(3.0), '3');
    expect(pluginNumberText(3), '3');
    expect(pluginNumberText(2.5), '2.5');
  });
}
