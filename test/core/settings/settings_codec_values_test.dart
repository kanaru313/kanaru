import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_codec_values.dart';

void main() {
  test('infinity clamps to the nearest bound', () {
    expect(intInRange(double.infinity, 0, 10, 3), 10);
    expect(intInRange(double.negativeInfinity, 0, 10, 3), 0);
  });

  test('NaN gives the fallback instead of throwing', () {
    expect(intInRange(double.nan, 0, 10, 3), 3);
    expect(doubleInRange(double.nan, 0, 1, 0.5), 0.5);
  });

  test('nonEmptyStringOrNull keeps only non-empty strings', () {
    expect(nonEmptyStringOrNull('a'), 'a');
    expect(nonEmptyStringOrNull(''), isNull);
    expect(nonEmptyStringOrNull(null), isNull);
    expect(nonEmptyStringOrNull(3), isNull);
  });
}
