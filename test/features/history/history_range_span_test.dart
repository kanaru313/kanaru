import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kanaru/features/history/history_range_span.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('vi');
  });

  group('historySpanText', () {
    test('a range inside one year writes the year once', () {
      expect(
        historySpanText('en', DateTime(2026, 9, 27), DateTime(2026, 10, 26)),
        'Sep 27 – Oct 26, 2026',
      );
      expect(
        historySpanText('vi', DateTime(2026, 9, 27), DateTime(2026, 10, 26)),
        '27 thg 9 – 26 thg 10, 2026',
      );
    });

    test('a range across two years writes both', () {
      expect(
        historySpanText('en', DateTime(2025, 12, 30), DateTime(2026, 1, 5)),
        'Dec 30, 2025 – Jan 5, 2026',
      );
    });

    test('one day is a single date', () {
      expect(
        historySpanText('en', DateTime(2026, 10, 26), DateTime(2026, 10, 26)),
        'Oct 26, 2026',
      );
    });
  });
}
