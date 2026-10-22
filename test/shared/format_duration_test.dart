import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/format_duration.dart';

void main() {
  test('formats durations', () {
    expect(formatDuration(Duration.zero), '0:00');
    expect(formatDuration(const Duration(minutes: 3, seconds: 5)), '3:05');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });
}
