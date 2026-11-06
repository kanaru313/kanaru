import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/proxy/resolved_streams.dart';
import 'package:kanaru/core/sources/proxy/stream_resolver.dart';

/// Counts resolves; each one gives a stream at `https://cdn.example.com/<n>`.
class _Resolves {
  final fresh = <bool>[];
  final abandoned = <bool Function()>[];
  DateTime? expiresAt;
  Object? error;
  Completer<void>? gate;

  Future<ResolvedStream> call(
    String key, {
    required bool fresh,
    required bool Function() abandoned,
  }) async {
    this.fresh.add(fresh);
    this.abandoned.add(abandoned);
    final n = this.fresh.length;
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    return ResolvedStream(
      url: Uri.parse('https://cdn.example.com/$n'),
      headers: const {},
      expiresAt: expiresAt,
      allowed: () => true,
    );
  }
}

void main() {
  late _Resolves resolves;
  late DateTime now;
  late ResolvedStreams streams;

  setUp(() {
    resolves = _Resolves();
    now = DateTime.utc(2026, 11, 6, 12);
    streams = ResolvedStreams(resolves.call, clock: () => now);
  });

  Future<String> path(Future<ResolvedStream> stream) async =>
      (await stream).url.path;

  test('requests of one playthrough share one resolve', () async {
    final playthrough = streams.begin('k', 'owner');
    final a = playthrough.current();
    final b = playthrough.current();
    expect(identical(a, b), isTrue);
    expect(await path(a), '/1');
    expect(await path(playthrough.current()), '/1');
    expect(resolves.fresh, [false]);
  });

  test('a stream is used until 60 s before it expires, then resolved again '
      'without spending the fresh resolve', () async {
    resolves.expiresAt = now.add(const Duration(minutes: 10));
    final playthrough = streams.begin('k', 'owner');
    expect(await path(playthrough.current()), '/1');

    now = now.add(const Duration(minutes: 8, seconds: 59));
    expect(await path(playthrough.current()), '/1');

    resolves.expiresAt = now.add(const Duration(minutes: 10));
    now = now.add(const Duration(seconds: 1));
    final again = playthrough.current();
    expect(await path(again), '/2');
    expect(resolves.fresh, [false, false]);

    // The fresh resolve is still there for a 403.
    expect(await path(playthrough.onForbidden(again)), '/3');
    expect(resolves.fresh, [false, false, true]);
  });

  test('an expiry already inside the margin counts as unknown', () async {
    resolves.expiresAt = now.add(const Duration(seconds: 30));
    final playthrough = streams.begin('k', 'owner');
    await playthrough.current();
    now = now.add(const Duration(minutes: 5));
    await playthrough.current();
    expect(resolves.fresh, [false]);
  });

  test(
    'the first 403 spends the fresh resolve, a later one kills the item',
    () async {
      final playthrough = streams.begin('k', 'owner');
      final first = playthrough.current();
      await first;
      final fresh = playthrough.onForbidden(first);
      expect(await path(fresh), '/2');
      expect(resolves.fresh, [false, true]);

      await expectLater(
        playthrough.onForbidden(fresh),
        throwsA(isA<PlaythroughEnded>()),
      );
      expect(playthrough.dead, isTrue);
      for (var i = 0; i < 5; i++) {
        await expectLater(
          playthrough.current(),
          throwsA(isA<PlaythroughEnded>()),
        );
      }
      expect(resolves.fresh, hasLength(2));
    },
  );

  test(
    'parallel 403s of the same stream share the one fresh resolve',
    () async {
      final playthrough = streams.begin('k', 'owner');
      final used = playthrough.current();
      await used;
      final a = playthrough.onForbidden(used);
      final b = playthrough.onForbidden(used);
      final c = playthrough.onForbidden(used);
      expect(await path(a), '/2');
      expect(await path(b), '/2');
      expect(await path(c), '/2');
      expect(resolves.fresh, [false, true]);
      expect(playthrough.dead, isFalse);
    },
  );

  test('a failed resolve kills the item without another call', () async {
    resolves.error = const ResolveFailure('unavailable');
    final playthrough = streams.begin('k', 'owner');
    await expectLater(playthrough.current(), throwsA(isA<ResolveFailure>()));
    await expectLater(playthrough.current(), throwsA(isA<PlaythroughEnded>()));
    expect(resolves.fresh, [false]);
  });

  test('a resolve longer than the deadline fails and is abandoned', () async {
    streams = ResolvedStreams(
      resolves.call,
      clock: () => now,
      resolveDeadline: const Duration(milliseconds: 50),
    );
    resolves.gate = Completer<void>();
    final playthrough = streams.begin('k', 'owner');
    await expectLater(playthrough.current(), throwsA(isA<ResolveFailure>()));
    expect(resolves.abandoned.single(), isTrue);
    resolves.gate!.complete();
  });

  test('begin starts a new playthrough with a new budget and abandons the '
      'old one', () async {
    final old = streams.begin('k', 'owner');
    final used = old.current();
    await used;
    await old.onForbidden(used);
    expect(resolves.abandoned.first(), isFalse);

    final next = streams.begin('k', 'owner');
    expect(old.ended, isTrue);
    expect(resolves.abandoned.first(), isTrue);
    expect(identical(streams.lookup('k'), next), isTrue);

    final again = next.current();
    expect(await path(again), '/3');
    expect(await path(next.onForbidden(again)), '/4');
    expect(resolves.fresh, [false, true, false, true]);
  });

  test(
    'a superseded playthrough hands its requests on to the newer one',
    () async {
      final old = streams.begin('k', 'owner');
      await old.current();
      final next = streams.begin('k', 'owner');

      final shared = old.current();
      expect(identical(shared, next.current()), isTrue);
      expect(await path(shared), '/2');
      // A 403 seen by the old body spends the newer playthrough's budget once.
      expect(await path(old.onForbidden(shared)), '/3');
      expect(resolves.fresh, [false, false, true]);

      streams.dropOwner('owner');
      await expectLater(old.current(), throwsA(isA<PlaythroughEnded>()));
    },
  );

  test('dropOwner ends and forgets only that owner\'s playthroughs', () async {
    final mine = streams.begin('a/1', 'a');
    final other = streams.begin('b/1', 'b');
    resolves.gate = Completer<void>();
    final pending = mine.current();

    streams.dropOwner('a');

    expect(mine.ended, isTrue);
    expect(resolves.abandoned.single(), isTrue);
    expect(streams.lookup('a/1'), isNull);
    expect(identical(streams.lookup('b/1'), other), isTrue);
    expect(other.ended, isFalse);
    resolves.gate!.complete();
    await pending;
  });
}
