import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/history/history_range.dart';
import 'package:kanaru/features/history/most_played_range.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  HistoryRangeState read() => container.read(mostPlayedRangeProvider);
  MostPlayedRangeNotifier notifier() =>
      container.read(mostPlayedRangeProvider.notifier);

  test('starts on the last 30 days', () {
    expect(read().preset, HistoryRangePreset.days30);
    expect(read().back, 0);
  });

  test('set shows exactly the given range', () {
    final day = DateTime(2026, 10, 23);
    notifier().set(
      HistoryRangeState(
        preset: HistoryRangePreset.custom,
        customStart: day,
        customEndInclusive: day,
      ),
    );
    expect(read().preset, HistoryRangePreset.custom);
    expect(read().customStart, day);
    expect(read().customEndInclusive, day);
  });

  test('a preset keeps a custom range remembered', () {
    final day = DateTime(2026, 10, 23);
    notifier()
      ..set(read().withCustom(day, day))
      ..withPreset(HistoryRangePreset.days7);
    expect(read().preset, HistoryRangePreset.days7);
    expect(read().customStart, day);
  });

  test('previous and next step the period and undo each other', () {
    notifier().previous();
    expect(read().back, 1);
    notifier().previous();
    expect(read().back, 2);
    notifier().next();
    expect(read().back, 1);
  });

  test(
    'the range stays while nothing listens, and for a new listener',
    () async {
      final sub = container.listen(mostPlayedRangeProvider, (_, _) {});
      notifier().withPreset(HistoryRangePreset.year);
      sub.close();
      await Future<void>.delayed(Duration.zero);

      // A remounted view reads the range the user left, not the default.
      final again = container.listen(mostPlayedRangeProvider, (_, _) {});
      expect(again.read().preset, HistoryRangePreset.year);
      again.close();
    },
  );
}
