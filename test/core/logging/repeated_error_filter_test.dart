import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/repeated_error_filter.dart';

/// A timer that fires only when the test says so.
class _FakeTimer implements Timer {
  _FakeTimer(this.callback);
  final void Function() callback;
  bool cancelled = false;

  void fire() {
    if (!cancelled) callback();
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

void main() {
  late DateTime now;
  late List<String> summaries;
  late List<_FakeTimer> timers;
  late RepeatedErrorFilter filter;

  setUp(() {
    now = DateTime(2026, 10, 20, 12);
    summaries = [];
    timers = [];
    filter = RepeatedErrorFilter(
      onSummary: summaries.add,
      now: () => now,
      startTimer: (delay, callback) {
        expect(delay, const Duration(seconds: 10));
        return _FakeTimer(callback)..also(timers.add);
      },
    );
  });

  test('a burst of 100 writes one record and counts 99', () {
    final written = [
      for (var i = 0; i < 100; i++) filter.shouldWrite('E #0 f'),
    ];
    expect(written.where((w) => w), hasLength(1));
    expect(written.first, isTrue);
    expect(summaries, isEmpty);
    expect(filter.close(), 'Uncaught error repeated ×99: E #0 f');
  });

  test('a different error is written and reports the pending count first', () {
    expect(filter.shouldWrite('A #0 f'), isTrue);
    expect(filter.shouldWrite('A #0 f'), isFalse);
    expect(filter.shouldWrite('A #0 f'), isFalse);
    expect(filter.shouldWrite('B #0 g'), isTrue);
    expect(summaries, ['Uncaught error repeated ×2: A #0 f']);
    expect(filter.close(), isNull);
  });

  test('the same type at another frame is another error', () {
    expect(filter.shouldWrite('A #0 f'), isTrue);
    expect(filter.shouldWrite('A #0 g'), isTrue);
    expect(summaries, isEmpty);
  });

  test('the window ending reports the count and starts over', () {
    expect(filter.shouldWrite('A #0 f'), isTrue);
    expect(filter.shouldWrite('A #0 f'), isFalse);
    timers.single.fire();
    expect(summaries, ['Uncaught error repeated ×1: A #0 f']);
    now = now.add(const Duration(seconds: 1));
    expect(filter.shouldWrite('A #0 f'), isTrue);
  });

  test('an error that arrives after the window is written again', () {
    expect(filter.shouldWrite('A #0 f'), isTrue);
    expect(filter.shouldWrite('A #0 f'), isFalse);
    now = now.add(const Duration(seconds: 10));
    expect(filter.shouldWrite('A #0 f'), isTrue);
    expect(summaries, ['Uncaught error repeated ×1: A #0 f']);
  });

  test('a single error leaves nothing to report', () {
    expect(filter.shouldWrite('A #0 f'), isTrue);
    timers.single.fire();
    expect(summaries, isEmpty);
    expect(filter.close(), isNull);
  });

  test('close cancels the timer and returns the pending summary once', () {
    filter.shouldWrite('A #0 f');
    filter.shouldWrite('A #0 f');
    expect(filter.close(), 'Uncaught error repeated ×1: A #0 f');
    expect(timers.single.cancelled, isTrue);
    expect(filter.close(), isNull);
    expect(summaries, isEmpty);
  });

  test('the label holds the type and the first stack line, capped', () {
    final stack = StackTrace.fromString('\n#0 fetch (a.dart:1)\n#1 main');
    expect(
      RepeatedErrorFilter.labelFor(StateError('x'), stack),
      'StateError #0 fetch (a.dart:1)',
    );
    expect(RepeatedErrorFilter.labelFor(StateError('x'), null), 'StateError');
    final long = RepeatedErrorFilter.labelFor(
      StateError('x'),
      StackTrace.fromString('#0 ${'f' * 500}'),
    );
    expect(long.length, lessThan(230));
  });
}

extension<T> on T {
  void also(void Function(T) block) => block(this);
}
