import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/app_exit_flush.dart';

/// Thrown by the fake `exit`, which cannot really end the test process.
class _Exited implements Exception {}

Never _exit() => throw _Exited();

void main() {
  group('flushBeforeExit', () {
    test('awaits every step', () async {
      final done = <int>[];
      await flushBeforeExit([
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          done.add(1);
        },
        () async => done.add(2),
      ]);

      expect(done..sort(), [1, 2]);
    });

    test('a throwing step does not stop the others', () async {
      var ran = false;
      await flushBeforeExit([
        () async => throw StateError('disk full'),
        () => throw StateError('thrown at once'),
        () async => ran = true,
      ]);

      expect(ran, isTrue);
    });

    test('gives up on a slow step at the cap', () async {
      final watch = Stopwatch()..start();
      await flushBeforeExit([
        () => Future<void>.delayed(const Duration(seconds: 5)),
      ], cap: const Duration(milliseconds: 20));

      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });

  group('exitOnClose', () {
    late List<String> calls;

    Future<void> Function() handler({
      Future<void> Function()? hide,
      Never Function()? exit,
      Future<void> Function()? pause,
      List<Future<void> Function()>? flushSteps,
      Future<void> Function()? destroy,
      Duration cap = const Duration(milliseconds: 200),
      // Long: the fallback exit after a successful destroy must not fire in
      // tests that do not look at it.
      Duration destroyTimeout = const Duration(hours: 1),
    }) => exitOnClose(
      hide:
          hide ??
          () async {
            calls.add('hide');
          },
      pause:
          pause ??
          () async {
            calls.add('pause');
          },
      flushSteps:
          flushSteps ??
          [
            () async {
              calls.add('flush recorder');
            },
            () async {
              calls.add('flush session');
            },
          ],
      destroy:
          destroy ??
          () async {
            calls.add('destroy');
          },
      exit: exit ?? _exit,
      cap: cap,
      destroyTimeout: destroyTimeout,
    );

    setUp(() => calls = []);

    test('hides, pauses, flushes, then destroys', () async {
      await handler()();

      expect(calls, [
        'hide',
        'pause',
        'flush recorder',
        'flush session',
        'destroy',
      ]);
    });

    test('flush steps start only after the pause call', () async {
      await handler(
        pause: () async {
          calls.add('pause starts');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          calls.add('pause ends');
        },
        flushSteps: [
          () async {
            calls.add('flush');
          },
        ],
      )();

      expect(calls.indexOf('pause starts'), lessThan(calls.indexOf('flush')));
    });

    test('exits when destroy hangs', () async {
      await expectLater(
        handler(
          destroy: () => Completer<void>().future,
          destroyTimeout: const Duration(milliseconds: 50),
        )(),
        throwsA(isA<_Exited>()),
      );
    });

    test('exits when destroy throws', () async {
      await expectLater(
        handler(destroy: () async => throw StateError('no window'))(),
        throwsA(isA<_Exited>()),
      );
    });

    test('destroys even when the flush times out', () async {
      await handler(
        flushSteps: [() => Completer<void>().future],
        cap: const Duration(milliseconds: 20),
      )();

      expect(calls.last, 'destroy');
    });

    test('a failing hide does not stop the exit', () async {
      await handler(hide: () async => throw StateError('no window'))();

      expect(calls.last, 'destroy');
    });

    test('a close request while destroying is ignored', () async {
      final destroyed = Completer<void>();
      final onClose = handler(
        destroy: () {
          calls.add('destroy');
          return destroyed.future;
        },
      );

      final first = onClose();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls.last, 'destroy');
      await onClose();
      destroyed.complete();
      await first;

      expect(calls.where((c) => c == 'destroy'), hasLength(1));
    });

    test('exits when the process outlives a successful destroy', () async {
      final exited = Completer<void>();
      await runZonedGuarded(() async {
        await handler(
          destroyTimeout: const Duration(milliseconds: 50),
          exit: () {
            exited.complete();
            throw _Exited();
          },
        )();
        expect(exited.isCompleted, isFalse);
        await exited.future.timeout(const Duration(seconds: 2));
      }, (error, _) => expect(error, isA<_Exited>()));

      expect(exited.isCompleted, isTrue);
    });

    test('a second close while flushing exits at once', () async {
      final release = Completer<void>();
      final onClose = handler(flushSteps: [() => release.future]);

      final first = onClose();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await expectLater(onClose(), throwsA(isA<_Exited>()));
      release.complete();
      await first;

      expect(calls.where((c) => c == 'hide'), hasLength(1));
      expect(calls.where((c) => c == 'pause'), hasLength(1));
    });
  });
}
