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
    expect(filter.close(), ['Uncaught error repeated ×99: E #0 f']);
  });

  test('a different error is written and does not end the first fold', () {
    expect(filter.shouldWrite('A #0 f'), isTrue);
    expect(filter.shouldWrite('A #0 f'), isFalse);
    expect(filter.shouldWrite('A #0 f'), isFalse);
    expect(filter.shouldWrite('B #0 g'), isTrue);
    expect(filter.shouldWrite('A #0 f'), isFalse);
    expect(summaries, isEmpty);
    expect(filter.close(), ['Uncaught error repeated ×3: A #0 f']);
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
    expect(filter.close(), isEmpty);
  });

  test('close cancels the timer and returns the pending summary once', () {
    filter.shouldWrite('A #0 f');
    filter.shouldWrite('A #0 f');
    expect(filter.close(), ['Uncaught error repeated ×1: A #0 f']);
    expect(timers.single.cancelled, isTrue);
    expect(filter.close(), isEmpty);
    expect(summaries, isEmpty);
  });

  test('errors that alternate are both folded', () {
    final written = [
      for (var i = 0; i < 4; i++) ...[
        filter.shouldWrite('A #0 f'),
        filter.shouldWrite('B #0 g'),
      ],
    ];
    expect(written, [true, true, false, false, false, false, false, false]);
    expect(filter.close(), [
      'Uncaught error repeated ×3: A #0 f',
      'Uncaught error repeated ×3: B #0 g',
    ]);
  });

  test('each key has its own window', () {
    expect(filter.shouldWrite('A'), isTrue);
    now = now.add(const Duration(seconds: 6));
    expect(filter.shouldWrite('B'), isTrue);
    expect(filter.shouldWrite('A'), isFalse);
    now = now.add(const Duration(seconds: 5)); // A: 11 s old, B: 5 s old.
    expect(filter.shouldWrite('B'), isFalse);
    expect(filter.shouldWrite('A'), isTrue);
    expect(summaries, ['Uncaught error repeated ×1: A']);
    expect(filter.close(), ['Uncaught error repeated ×1: B']);
  });

  test('a window ending reports only its own key', () {
    filter.shouldWrite('A');
    filter.shouldWrite('B');
    filter.shouldWrite('A');
    timers[0].fire();
    expect(summaries, ['Uncaught error repeated ×1: A']);
    expect(filter.close(), isEmpty);
  });

  test('the oldest key is reported and dropped past the limit', () {
    for (var i = 0; i < 8; i++) {
      filter.shouldWrite('E$i');
    }
    filter.shouldWrite('E0');
    expect(filter.shouldWrite('E8'), isTrue);
    expect(summaries, ['Uncaught error repeated ×1: E0']);
    expect(timers.first.cancelled, isTrue);
    // E0 was evicted: it is written again, not counted.
    expect(filter.shouldWrite('E0'), isTrue);
  });

  group('keyFor', () {
    test('holds type, first stack line and text', () {
      final stack = StackTrace.fromString('\n#0 fetch (a.dart:1)\n#1 main');
      expect(
        RepeatedErrorFilter.keyFor(StateError('x'), stack),
        'StateError #0 fetch (a.dart:1) | Bad state: x',
      );
    });

    test('skips frames inside the SDK and the framework', () {
      final stack = StackTrace.fromString(
        '#0 List.[] (dart:core-patch/growable_array.dart:264:36)\n'
        '#1 Element.rebuild (package:flutter/src/widgets/framework.dart:1:1)\n'
        '#2 _AssertionError._doThrowNew (dart:core-patch/errors_patch.dart:5)\n'
        '#3 Row.build (package:kanaru/features/row.dart:12:3)\n'
        '#4 main',
      );
      expect(
        RepeatedErrorFilter.keyFor(RangeError('x'), stack),
        contains('#3 Row.build (package:kanaru/features/row.dart:12:3)'),
      );
    });

    test('different call sites under the same SDK frame differ', () {
      StackTrace at(String site) => StackTrace.fromString(
        '#0 List.[] (dart:core-patch/growable_array.dart:264:36)\n'
        '#1 $site',
      );
      expect(
        RepeatedErrorFilter.keyFor(RangeError('i'), at('one (a.dart:1:1)')),
        isNot(
          RepeatedErrorFilter.keyFor(RangeError('i'), at('two (b.dart:2:2)')),
        ),
      );
      expect(
        RepeatedErrorFilter.keyFor(RangeError('i'), at('one (a.dart:1:1)')),
        RepeatedErrorFilter.keyFor(RangeError('i'), at('one (a.dart:1:1)')),
      );
    });

    test('a stack made only of SDK frames is told apart by a hash', () {
      StackTrace sdk(String fn) => StackTrace.fromString(
        '#0 $fn (dart:core/x.dart:1:1)\n#1 run (dart:async/y.dart:2:2)',
      );
      expect(
        RepeatedErrorFilter.keyFor(StateError('s'), sdk('a')),
        isNot(RepeatedErrorFilter.keyFor(StateError('s'), sdk('b'))),
      );
    });

    test('the text tells errors without a stack apart', () {
      expect(
        RepeatedErrorFilter.keyFor(StateError('one'), null),
        isNot(RepeatedErrorFilter.keyFor(StateError('two'), null)),
      );
      expect(
        RepeatedErrorFilter.keyFor(StateError('one'), null),
        'StateError | Bad state: one',
      );
    });

    test('long text and long frames are capped', () {
      final key = RepeatedErrorFilter.keyFor(
        StateError('t' * 500),
        StackTrace.fromString('#0 ${'f' * 500}'),
      );
      expect(key.length, lessThan(450));
    });
  });
}

extension<T> on T {
  void also(void Function(T) block) => block(this);
}
