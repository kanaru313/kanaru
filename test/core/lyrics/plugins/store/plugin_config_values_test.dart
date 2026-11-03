import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_config_values.dart';

PluginConfigField _input(
  PluginInputFormat format, {
  int? minLength,
  int? maxLength,
  num? min,
  num? max,
}) => PluginConfigField(
  key: 'k',
  title: 'K',
  mode: PluginConfigMode.input,
  inputFormat: format,
  minLength: minLength,
  maxLength: maxLength,
  min: min,
  max: max,
);

PluginConfigField _list(
  PluginListFormat format, {
  int? minItems,
  int? maxItems,
}) => PluginConfigField(
  key: 'k',
  title: 'K',
  mode: PluginConfigMode.list,
  listFormat: format,
  minItems: minItems,
  maxItems: maxItems,
);

const _opts = [
  PluginConfigOption(value: 'a', title: 'A'),
  PluginConfigOption(value: 'b', title: 'B'),
  PluginConfigOption(value: 'c', title: 'C'),
];

const _map = PluginConfigField(
  key: 'k',
  title: 'K',
  mode: PluginConfigMode.map,
  maxItems: 2,
);

void main() {
  void expectProblem(
    PluginConfigField f,
    Object? value,
    PluginValueProblem? problem,
  ) => expect(pluginValueProblem(f, value), problem, reason: '$value');

  test('pluginValueFits is "no problem"', () {
    expect(pluginValueFits(_input(PluginInputFormat.text), 'a'), isTrue);
    expect(pluginValueFits(_input(PluginInputFormat.text), 1), isFalse);
  });

  group('text', () {
    final f = _input(PluginInputFormat.text, minLength: 2, maxLength: 4);
    test('lengths count code points', () {
      expectProblem(f, 'ab', null);
      expectProblem(f, '😀😀', null);
      expectProblem(f, 'a', PluginValueProblem.tooShort);
      expectProblem(f, '😀' * 5, PluginValueProblem.tooLong);
      expectProblem(f, 1, PluginValueProblem.wrongType);
    });

    test('default cap is 2000', () {
      final plain = _input(PluginInputFormat.multiline);
      expectProblem(plain, 'x' * 2000, null);
      expectProblem(plain, 'x' * 2001, PluginValueProblem.tooLong);
    });

    test('secret has the same cap', () {
      final s = _input(PluginInputFormat.secret);
      expectProblem(s, 'x' * 2000, null);
      expectProblem(s, 'x' * 2001, PluginValueProblem.tooLong);
    });
  });

  group('numbers', () {
    final n = _input(PluginInputFormat.number, min: -1, max: 10);
    final i = _input(PluginInputFormat.integer, min: 0, max: 10);

    test('number', () {
      expectProblem(n, 2.5, null);
      expectProblem(n, -2, PluginValueProblem.belowMin);
      expectProblem(n, 11, PluginValueProblem.aboveMax);
      expectProblem(n, double.nan, PluginValueProblem.wrongType);
      expectProblem(n, double.infinity, PluginValueProblem.wrongType);
      expectProblem(n, true, PluginValueProblem.wrongType);
    });

    test('integer', () {
      expectProblem(i, 3, null);
      expectProblem(i, 3.5, PluginValueProblem.notInteger);
      expectProblem(i, 3.0, PluginValueProblem.notInteger);
      expectProblem(i, -1, PluginValueProblem.belowMin);
      expectProblem(
        _input(PluginInputFormat.integer),
        9007199254740992,
        PluginValueProblem.aboveMax,
      );
      expectProblem(
        _input(PluginInputFormat.integer),
        -9007199254740992,
        PluginValueProblem.belowMin,
      );
      expectProblem(_input(PluginInputFormat.integer), 9007199254740991, null);
    });

    test('text is never read as a number', () {
      expectProblem(n, '2.5', PluginValueProblem.wrongType);
      expectProblem(n, 'x', PluginValueProblem.wrongType);
      expectProblem(i, '3', PluginValueProblem.wrongType);
      expectProblem(n, 99, PluginValueProblem.aboveMax);
      expectProblem(n, double.infinity, PluginValueProblem.wrongType);
    });
  });

  group('url', () {
    final f = _input(PluginInputFormat.url);
    test('https with a host only', () {
      expectProblem(f, 'https://example.com:8443/a?b=1', null);
      expectProblem(f, 'HTTPS://example.com', null);
      expectProblem(f, 'http://example.com', PluginValueProblem.badUrl);
      expectProblem(f, 'ftp://example.com', PluginValueProblem.badUrl);
      expectProblem(f, 'https://', PluginValueProblem.badUrl);
      expectProblem(f, 'https://u:p@example.com', PluginValueProblem.badUrl);
      expectProblem(f, 'https://exa mple.com', PluginValueProblem.badUrl);
      expectProblem(f, 'https://@example.com', PluginValueProblem.badUrl);
      expectProblem(f, 'https://exam\u200bple.com', PluginValueProblem.badUrl);
      expectProblem(f, 'example.com', PluginValueProblem.badUrl);
      expectProblem(
        f,
        'https://a.io/${'x' * 2000}',
        PluginValueProblem.tooLong,
      );
    });
  });

  group('select', () {
    test('single', () {
      const f = PluginConfigField(
        key: 'k',
        title: 'K',
        mode: PluginConfigMode.select,
        options: _opts,
      );
      expectProblem(f, 'a', null);
      expectProblem(f, 'z', PluginValueProblem.notOption);
      expectProblem(f, 1, PluginValueProblem.wrongType);
    });

    test('multiple', () {
      const f = PluginConfigField(
        key: 'k',
        title: 'K',
        mode: PluginConfigMode.select,
        selectFormat: PluginSelectFormat.multiple,
        options: _opts,
        minItems: 1,
        maxItems: 2,
      );
      expectProblem(f, <dynamic>['a', 'b'], null);
      expectProblem(f, <String>[], PluginValueProblem.tooFewItems);
      expectProblem(f, ['a', 'b', 'c'], PluginValueProblem.tooManyItems);
      expectProblem(f, ['z'], PluginValueProblem.notOption);
      expectProblem(f, ['a', 'a'], PluginValueProblem.badItem);
      expectProblem(f, [1], PluginValueProblem.badItem);
      expectProblem(f, 'a', PluginValueProblem.wrongType);
    });
  });

  test('toggle', () {
    const f = PluginConfigField(
      key: 'k',
      title: 'K',
      mode: PluginConfigMode.toggle,
    );
    expectProblem(f, false, null);
    expectProblem(f, 'true', PluginValueProblem.wrongType);
  });

  group('list', () {
    test('text items are non-empty and short', () {
      final f = _list(PluginListFormat.text, minItems: 1, maxItems: 2);
      expectProblem(f, <dynamic>['a', 'b'], null);
      expectProblem(f, <String>[], PluginValueProblem.tooFewItems);
      expectProblem(f, ['a', 'b', 'c'], PluginValueProblem.tooManyItems);
      expectProblem(f, [''], PluginValueProblem.badItem);
      expectProblem(f, ['  '], PluginValueProblem.badItem);
      expectProblem(f, ['x' * 2001], PluginValueProblem.badItem);
      expectProblem(f, [1], PluginValueProblem.badItem);
      expectProblem(f, 'a', PluginValueProblem.wrongType);
    });

    test('50 items pass and 51 do not', () {
      final f = _list(PluginListFormat.text);
      expectProblem(f, List.filled(50, 'a'), null);
      expectProblem(f, List.filled(51, 'a'), PluginValueProblem.tooManyItems);
    });

    test('number and integer items', () {
      final n = _list(PluginListFormat.number);
      expectProblem(n, [1, 2.5], null);
      expectProblem(n, ['1'], PluginValueProblem.badItem);
      expectProblem(n, [double.nan], PluginValueProblem.badItem);
      final i = _list(PluginListFormat.integer);
      expectProblem(i, [1, 2], null);
      expectProblem(i, [1.5], PluginValueProblem.badItem);
      expectProblem(i, [9007199254740992], PluginValueProblem.badItem);
    });

    test('url items', () {
      final f = _list(PluginListFormat.url);
      expectProblem(f, ['https://a.io'], null);
      expectProblem(f, ['http://a.io'], PluginValueProblem.badItem);
    });
  });

  group('map', () {
    test('keys and values', () {
      expectProblem(_map, <String, dynamic>{'a': 'x', 'b': ''}, null);
      expectProblem(_map, {'': 'x'}, PluginValueProblem.badKey);
      expectProblem(_map, {'k' * 101: 'x'}, PluginValueProblem.badKey);
      expectProblem(_map, {'k' * 100: 'x'}, null);
      expectProblem(_map, {' a': 'x'}, PluginValueProblem.badKey);
      expectProblem(_map, {'a ': 'x'}, PluginValueProblem.badKey);
      expectProblem(_map, {'a\u0000': 'x'}, PluginValueProblem.badKey);
      expectProblem(_map, {'a​': 'x'}, PluginValueProblem.badKey);
      expectProblem(_map, {'__proto__': 'x'}, PluginValueProblem.badKey);
      expectProblem(_map, {'a': 1}, PluginValueProblem.badItem);
      expectProblem(_map, {'a': 'x' * 2001}, PluginValueProblem.badItem);
      expectProblem(_map, ['a'], PluginValueProblem.wrongType);
    });

    test('keys are case sensitive and counted', () {
      expectProblem(_map, {'a': '1', 'A': '2'}, null);
      expectProblem(_map, {
        'a': '1',
        'b': '2',
        'c': '3',
      }, PluginValueProblem.tooManyItems);
      expectProblem(
        const PluginConfigField(
          key: 'k',
          title: 'K',
          mode: PluginConfigMode.map,
        ),
        {for (var i = 0; i < 51; i++) 'k$i': 'v'},
        PluginValueProblem.tooManyItems,
      );
    });
  });
}
