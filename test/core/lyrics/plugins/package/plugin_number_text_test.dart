import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_number_text.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_config_value_rules.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_config_values.dart';

void main() {
  group('parsePluginNumberText', () {
    const accepted = {
      '0': 0,
      '-1': -1,
      '1.5': 1.5,
      '1e5': 1e5,
      '1E-3': 1e-3,
      '-2.5e+3': -2500,
    };
    accepted.forEach((text, value) {
      test('accepts $text', () => expect(parsePluginNumberText(text), value));
    });
    for (final text in [
      '+5',
      '.5',
      '5.',
      '0x10',
      ' 1',
      '1 ',
      '1\n',
      'Infinity',
      'NaN',
      '',
      '-',
      '1e',
      '1e+',
      '--1',
      '1.2.3',
      '1e400',
      '١٢',
    ]) {
      test(
        'rejects "$text"',
        () => expect(parsePluginNumberText(text), isNull),
      );
    }
    test('whole mode takes integers only', () {
      expect(parsePluginNumberText('12', whole: true), 12);
      expect(parsePluginNumberText('-7', whole: true), -7);
      expect(parsePluginNumberText('1.5', whole: true), isNull);
    });
    test('a very long near-miss returns quickly', () {
      final text = '${'1' * 100000}x';
      final watch = Stopwatch()..start();
      expect(parsePluginNumberText(text), isNull);
      expect(watch.elapsedMilliseconds, lessThan(500));
    });
  });

  group('pluginUrlProblem authority', () {
    const ok = [
      'https://medium.com/@user',
      'https://host?x=@y',
      'https://host#@y',
    ];
    const bad = [
      'https://user@host',
      'https://@host',
      'http://host',
      'host.example',
    ];
    for (final url in ok) {
      test('accepts $url', () => expect(pluginUrlProblem(url), isNull));
    }
    for (final url in bad) {
      test('refuses $url', () {
        expect(pluginUrlProblem(url), PluginValueProblem.badUrl);
      });
    }
  });
}
