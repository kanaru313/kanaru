import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/history/most_played_limit.dart';

void main() {
  group('mostPlayedTopLimitProvider', () {
    test('defaults to 100', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(mostPlayedTopLimitProvider), defaultHistoryTopLimit);
      expect(container.read(mostPlayedTopLimitProvider), 100);
    });

    test('sets presets directly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mostPlayedTopLimitProvider.notifier);

      for (final limit in [5, 10, 50, 100]) {
        notifier.set(limit);
        expect(container.read(mostPlayedTopLimitProvider), limit);
      }
    });

    test('clamps lower bound to 1', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mostPlayedTopLimitProvider.notifier);

      notifier.set(0);
      expect(container.read(mostPlayedTopLimitProvider), minCustomTopLimit);
      expect(container.read(mostPlayedTopLimitProvider), 1);

      notifier.set(-10);
      expect(container.read(mostPlayedTopLimitProvider), 1);
    });

    test('clamps upper bound to 1000', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mostPlayedTopLimitProvider.notifier);

      notifier.set(1500);
      expect(container.read(mostPlayedTopLimitProvider), maxCustomTopLimit);
      expect(container.read(mostPlayedTopLimitProvider), 1000);
    });
  });
}
