import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/remote_open_wait.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/sources/source_models.dart';

void main() {
  const a = Track(uri: '/music/a.flac', title: 'A');
  const b = Track(uri: '/music/b.flac', title: 'B');
  const c = Track(uri: '/music/c.flac', title: 'C');
  const url = 'http://127.0.0.1:4000/tok/source-plugin/inst/item1';
  const shortWait = Duration(milliseconds: 20);

  late OpenCoordinator opens;

  setUp(() => opens = OpenCoordinator());

  OpenTicket begin({
    Track? next,
    bool play = true,
    Duration start = Duration.zero,
    bool waits = true,
  }) => opens.begin(next: next, play: play, start: start, waits: waits);

  group('generation rule', () {
    test('the newest open may start, an older one gave up at the call', () {
      final older = begin();
      final newer = begin();

      expect(older.gaveUp, isTrue);
      expect(newer.gaveUp, isFalse);
      expect(older.tryStart(), isFalse);
      expect(newer.tryStart(), isTrue);
    });

    test('an older open stays out whatever order the waits end in', () {
      final first = begin();
      final second = begin();
      final third = begin(waits: false);

      // The newest, local one runs first; the waiting ones come after.
      expect(third.tryStart(), isTrue);
      expect(second.tryStart(), isFalse);
      expect(first.tryStart(), isFalse);
    });

    test('a local open called during a wait is not skipped by it', () {
      final waiting = begin();
      final local = begin(waits: false);

      expect(local.tryStart(), isTrue);
      expect(waiting.gaveUp, isTrue);
    });

    test('an open that is running goes on when a newer one is called', () {
      final running = begin(waits: false);
      expect(running.tryStart(), isTrue);

      final newer = begin();

      expect(running.gaveUp, isFalse);
      expect(newer.gaveUp, isFalse);
      expect(opens.pending, 2);
    });

    test('a newer open ends the signal of an older one at the call', () async {
      final older = begin();
      var signalled = false;
      unawaited(older.onGaveUp.then((_) => signalled = true));

      begin();
      await Future<void>.delayed(Duration.zero);

      expect(signalled, isTrue);
    });
  });

  group('pending count', () {
    test('counts every open from its call until it ran or gave up', () {
      expect(opens.pending, 0);
      final first = begin();
      expect(opens.pending, 1);
      final second = begin(waits: false);
      // The first one gave up at the second call and left the count.
      expect(opens.pending, 1);

      expect(second.tryStart(), isTrue);
      expect(opens.pending, 1);
      second.finish();
      expect(opens.pending, 0);
      first.finish();
      expect(opens.pending, 0);
    });

    test('finish and giving up release only once', () {
      final ticket = begin();
      begin();
      ticket.finish();
      ticket.finish();

      expect(opens.pending, 1);
    });

    test('a stop releases the waiting open at once', () {
      begin();
      opens.onStop();

      expect(opens.pending, 0);
    });

    test('dispose releases the opens that have not started', () {
      begin();
      begin(waits: false);
      opens.dispose();

      expect(opens.pending, 0);
    });
  });

  group('calls made during a wait', () {
    test('play and pause: the last press decides play', () {
      final ticket = begin();

      opens.onPlayPause(playing: false);
      expect(ticket.play, isFalse);
      opens.onPlayPause(playing: true);
      expect(ticket.play, isTrue);
      opens.onPlayPause(playing: false);
      expect(ticket.play, isFalse);
    });

    test('play and pause leave an open that is not waiting alone', () {
      final queued = begin(waits: false);

      opens.onPlayPause(playing: false);

      expect(queued.play, isTrue);
    });

    test('seek becomes the start, the last one wins', () {
      final ticket = begin(start: const Duration(seconds: 3));

      expect(opens.onSeek(const Duration(seconds: 40)), isTrue);
      expect(opens.onSeek(const Duration(seconds: 55)), isTrue);

      expect(ticket.start, const Duration(seconds: 55));
    });

    test('seek with no waiting open is left to the engine', () {
      begin(waits: false);

      expect(opens.onSeek(const Duration(seconds: 5)), isFalse);
    });

    test('seek after the wait ended is left to the chain', () {
      final ticket = begin()..leaveWait();

      expect(opens.onSeek(const Duration(seconds: 5)), isFalse);
      expect(ticket.start, Duration.zero);
    });

    test('setNext replaces the next track of a waiting open', () {
      final ticket = begin(next: a);

      expect(opens.onSetNext(b), isTrue);
      expect(opens.onSetNext(c), isTrue);

      expect(ticket.next, c);
    });

    test('setNext also reaches an open already in the chain', () {
      final ticket = begin(next: a)..leaveWait();

      expect(opens.onSetNext(b), isTrue);

      expect(ticket.next, b);
    });

    test('setNext(null) clears the next track', () {
      final ticket = begin(next: a);

      expect(opens.onSetNext(null), isTrue);

      expect(ticket.next, isNull);
    });

    test('setNext goes to the chain when no open waits to run', () {
      expect(opens.onSetNext(a), isFalse);

      final running = begin(waits: false);
      expect(running.tryStart(), isTrue);
      expect(opens.onSetNext(a), isFalse);

      running.finish();
      expect(opens.onSetNext(a), isFalse);
    });

    test('setNext goes only to the newest open', () {
      final older = begin(next: a);
      final newer = begin(next: b);

      expect(opens.onSetNext(c), isTrue);

      expect(older.next, a);
      expect(newer.next, c);
    });

    test('stop makes the waiting open give up', () {
      final ticket = begin();

      opens.onStop();

      expect(ticket.gaveUp, isTrue);
      expect(ticket.tryStart(), isFalse);
    });

    test('stop leaves an open already in the chain alone', () {
      final ticket = begin()..leaveWait();

      opens.onStop();

      expect(ticket.gaveUp, isFalse);
      expect(ticket.tryStart(), isTrue);
    });

    test('after a stop nothing takes seek or setNext', () {
      begin();
      opens.onStop();

      expect(opens.onSeek(const Duration(seconds: 1)), isFalse);
      expect(opens.onSetNext(a), isFalse);
    });
  });

  group('waitForRemoteFormat', () {
    Future<String?> wait(
      OpenTicket ticket, {
      Future<String> Function()? handOut,
      required Future<RemoteStreamFormat?> Function(String url) formatOf,
      Duration grace = Duration.zero,
      Duration timeout = shortWait,
      List<Object>? errors,
    }) => waitForRemoteFormat(
      ticket: ticket,
      handOut: handOut ?? () async => url,
      formatOf: formatOf,
      grace: grace,
      wait: timeout,
      onError: errors?.add,
    );

    test('returns the URL once the format is known', () async {
      final asked = <String>[];

      final result = await wait(
        begin(),
        formatOf: (u) async {
          asked.add(u);
          return RemoteStreamFormat.hls;
        },
      );

      expect(result, url);
      expect(asked, [url]);
    });

    test('asks nothing when a newer open comes within the grace', () async {
      final ticket = begin();
      var handedOut = false;
      var asked = false;
      final result = wait(
        ticket,
        grace: const Duration(seconds: 5),
        handOut: () async {
          handedOut = true;
          return url;
        },
        formatOf: (_) async {
          asked = true;
          return null;
        },
      );

      begin();

      expect(await result, isNull);
      expect(handedOut, isFalse);
      expect(asked, isFalse);
    });

    test('a stop within the grace begins nothing', () async {
      final ticket = begin();
      var handedOut = false;
      final result = wait(
        ticket,
        grace: const Duration(seconds: 5),
        handOut: () async {
          handedOut = true;
          return url;
        },
        formatOf: (_) async => null,
      );

      opens.onStop();

      expect(await result, isNull);
      expect(handedOut, isFalse);
    });

    test('gives up at once when a newer open comes during formatOf', () async {
      final ticket = begin();
      final never = Completer<RemoteStreamFormat?>();
      final result = wait(
        ticket,
        formatOf: (_) => never.future,
        timeout: const Duration(seconds: 30),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));

      begin(waits: false);

      expect(await result, isNull);
    });

    test('gives up at once when a stop comes during formatOf', () async {
      final ticket = begin();
      final never = Completer<RemoteStreamFormat?>();
      final result = wait(
        ticket,
        formatOf: (_) => never.future,
        timeout: const Duration(seconds: 30),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));

      opens.onStop();

      expect(await result, isNull);
    });

    test('a late answer after giving up opens nothing', () async {
      final ticket = begin();
      final late = Completer<RemoteStreamFormat?>();
      final result = wait(ticket, formatOf: (_) => late.future);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      begin(waits: false);
      expect(await result, isNull);

      late.complete(RemoteStreamFormat.hls);
      await Future<void>.delayed(Duration.zero);

      expect(ticket.tryStart(), isFalse);
    });

    test(
      'a newer open ends the wait while the URL is being handed out',
      () async {
        final ticket = begin();
        final slow = Completer<String>();
        final result = wait(
          ticket,
          handOut: () => slow.future,
          formatOf: (_) async => RemoteStreamFormat.hls,
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));

        begin();

        expect(await result, isNull);
      },
    );

    test('a null answer still opens the track', () async {
      expect(await wait(begin(), formatOf: (_) async => null), url);
    });

    test('an error is reported and the track still opens', () async {
      final errors = <Object>[];

      final result = await wait(
        begin(),
        formatOf: (_) async => throw StateError('boom'),
        errors: errors,
      );

      expect(result, url);
      expect(errors.single, isA<StateError>());
    });

    test('a formatOf that throws at once is caught too', () async {
      final errors = <Object>[];

      final result = await wait(
        begin(),
        formatOf: (_) => throw StateError('boom'),
        errors: errors,
      );

      expect(result, url);
      expect(errors, hasLength(1));
    });

    test(
      'a formatOf slower than the wait opens the track and reports',
      () async {
        final never = Completer<RemoteStreamFormat?>();
        final errors = <Object>[];

        final result = await wait(
          begin(),
          formatOf: (_) => never.future,
          errors: errors,
        );

        expect(result, url);
        expect(errors.single, isA<TimeoutException>());
      },
    );

    test('a handOut that fails returns null and reports', () async {
      final errors = <Object>[];
      final ticket = begin();

      final result = await wait(
        ticket,
        handOut: () async => throw StateError('proxy down'),
        formatOf: (_) async => null,
        errors: errors,
      );

      expect(result, isNull);
      expect(ticket.gaveUp, isFalse);
      expect(errors.single, isA<StateError>());
    });

    test('the grace is a named constant of 300 ms', () {
      expect(remoteOpenGrace, const Duration(milliseconds: 300));
    });
  });
}
