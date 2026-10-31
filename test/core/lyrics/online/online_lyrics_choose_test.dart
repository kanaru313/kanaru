import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_actions.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_source_provider.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';

import 'fake_lyrics_provider.dart';
import 'status_test_rig.dart';

const _lrc = '[00:00.00]local';

void main() {
  late StatusRig rig;
  final song = fakeSong('/m/a.flac');
  final target = LyricsTarget.fromTrack(song);
  final picked = fakeCandidate(
    remoteId: 'pick',
    body: const LyricsBody(syncedLrc: '[00:02.00] picked'),
  );

  OnlineLyricsActions actions() =>
      rig.container.read(onlineLyricsActionsProvider);
  LyricsFound found() => rig.status as LyricsFound;
  LyricsNone none() => rig.status as LyricsNone;
  LyricsSourceResolution source() =>
      rig.container.read(playingLyricsSourceProvider)!;
  Future<void> show({
    bool autoFetch = false,
    bool local = true,
    LyricsCandidate? lookup,
  }) async {
    rig = await createStatusRig(autoFetch: autoFetch);
    rig.fake.lookupResult = lookup;
    if (local) rig.sidecar.byPath['/m/a.flac'] = _lrc;
    rig.watch();
    await rig.play([song]);
    await rig.until(() => rig.status is! LyricsReading);
    await rig.settle();
  }

  group('choose', () {
    test('local and online round-trip and keep the pick', () async {
      await show();
      await actions().pick(target, picked);
      await rig.until(() => found().origin != null);
      expect(source().effective, LyricsChoice.online);

      await actions().choose(target, LyricsChoice.local);
      await rig.until(() => found().origin == null);
      expect(found().lyrics.lines.single.text, 'local');
      expect(source().chosen, LyricsChoice.local);
      expect(source().effective, LyricsChoice.local);
      expect(source().pin!.hasPick, isTrue);

      await actions().choose(target, LyricsChoice.online);
      await rig.until(() => found().origin != null);
      expect(found().origin!.remoteId, 'pick');
      expect(source().chosen, LyricsChoice.online);
      expect(rig.requests, 0);
    });

    test('automatic keeps the pick, and online brings it back', () async {
      await show();
      await actions().pick(target, picked);
      await rig.until(() => found().origin != null);

      await actions().choose(target, LyricsChoice.auto);
      await rig.until(() => found().origin == null);

      final pin = await rig.h.db.watchLyricsPin(target.trackKey).first;
      expect(pin!.mode, isNull);
      expect(pin.remoteId, 'pick');
      expect(source().chosen, LyricsChoice.auto);
      expect(source().effective, LyricsChoice.auto);
      expect(source().pin!.hasPick, isTrue);
      expect(source().hasLocal, isTrue);

      // Choosing automatic again writes nothing.
      final writes = <Object?>[];
      final sub = rig.h.db.tableUpdates().listen(writes.add);
      addTearDown(sub.cancel);
      await actions().choose(target, LyricsChoice.auto);
      await rig.settle();
      expect(writes, isEmpty);

      await actions().choose(target, LyricsChoice.online);
      await rig.until(() => found().origin != null);
      expect(found().origin!.remoteId, 'pick');
      expect(source().chosen, LyricsChoice.online);
    });

    test('online without a pick does nothing', () async {
      await show();

      await actions().choose(target, LyricsChoice.online);
      await rig.settle();

      expect(await rig.h.db.watchLyricsPin(target.trackKey).first, isNull);
      expect(found().origin, isNull);
    });

    test('online on a row that has only a choice does nothing', () async {
      await show();
      await actions().choose(target, LyricsChoice.off);
      await rig.until(() => rig.status is LyricsNone);

      await actions().choose(target, LyricsChoice.online);
      await rig.settle();

      final pin = await rig.h.db.watchLyricsPin(target.trackKey).first;
      expect(pin!.mode, 'off');
    });

    test('off shows no lyrics and asks for nothing', () async {
      await show(
        autoFetch: true,
        local: false,
        lookup: fakeCandidate(remoteId: 'x'),
      );
      await rig.until(() => rig.status is LyricsFound);
      await rig.settle();
      final requests = rig.requests;

      await actions().choose(target, LyricsChoice.off);
      await rig.until(() => rig.status is LyricsNone);

      expect(none().reason, LyricsNoneReason.off);
      expect(source().effective, LyricsChoice.off);
      expect(rig.requests, requests);

      await actions().choose(target, LyricsChoice.auto);
      await rig.until(() => rig.status is LyricsFound);
      expect(rig.requests, requests);
    });

    test(
      'local without local lyrics resolves as auto and writes nothing',
      () async {
        await show(local: false);
        await actions().pick(target, picked);
        await rig.until(() => rig.status is LyricsFound);
        await actions().choose(target, LyricsChoice.local);
        await rig.until(() => rig.status is LyricsNone);
        final before = await rig.h.db.watchLyricsPin(target.trackKey).first;

        final writes = <Object?>[];
        final sub = rig.h.db.tableUpdates().listen(writes.add);
        addTearDown(sub.cancel);
        await rig.rewatch();
        await rig.settle();

        expect(none().reason, LyricsNoneReason.noLyrics);
        expect(source().chosen, LyricsChoice.local);
        expect(source().effective, LyricsChoice.auto);
        expect(source().hasLocal, isFalse);
        expect(await rig.h.db.watchLyricsPin(target.trackKey).first, before);
        expect(writes, isEmpty);
        expect(rig.requests, 0);
      },
    );

    test('automatic and local read the song\'s lyrics again', () async {
      await show(local: false);
      await actions().choose(target, LyricsChoice.local);
      await rig.settle();
      expect(none().reason, LyricsNoneReason.noLyrics);

      rig.sidecar.byPath['/m/a.flac'] = _lrc;
      await actions().choose(target, LyricsChoice.auto);
      await rig.until(() => rig.status is LyricsFound);

      expect(found().lyrics.lines.single.text, 'local');
    });

    test('choosing what is stored writes and emits nothing', () async {
      await show();
      await actions().choose(target, LyricsChoice.local);
      await rig.until(() => source().chosen == LyricsChoice.local);
      await rig.settle();
      final lyrics = found().lyrics;
      final seen = <LyricsSourceResolution?>[];
      final sub = rig.container.listen(
        playingLyricsSourceProvider,
        (_, next) => seen.add(next),
      );
      addTearDown(sub.close);
      final writes = <Object?>[];
      final writeSub = rig.h.db.tableUpdates().listen(writes.add);
      addTearDown(writeSub.cancel);

      await actions().choose(target, LyricsChoice.local);
      await actions().choose(target, LyricsChoice.local);
      await rig.settle();

      // Only the write is skipped; the song's lyrics are read again.
      expect(writes, isEmpty);
      expect(found().lyrics.lines.single.text, 'local');

      await actions().choose(target, LyricsChoice.auto);
      await rig.settle();
      writes.clear();
      await actions().choose(target, LyricsChoice.auto);
      expect(writes, isEmpty);
      expect(seen.every((v) => v!.hasLocal), isTrue);
      expect(lyrics, isNotNull);
    });

    test('online and off of the stored mode keep the same lyrics', () async {
      await show();
      await actions().pick(target, picked);
      await rig.until(() => rig.status is LyricsFound);
      await rig.settle();
      final lyrics = found().lyrics;
      final writes = <Object?>[];
      final sub = rig.h.db.tableUpdates().listen(writes.add);
      addTearDown(sub.cancel);

      await actions().choose(target, LyricsChoice.online);
      await rig.settle();
      expect(writes, isEmpty);
      expect(identical(found().lyrics, lyrics), isTrue);

      await actions().choose(target, LyricsChoice.off);
      await rig.until(() => rig.status is LyricsNone);
      writes.clear();
      await actions().choose(target, LyricsChoice.off);
      await rig.settle();
      expect(writes, isEmpty);
    });

    test('automatic with no row reads a new .lrc', () async {
      await show(local: false);
      expect(none().reason, LyricsNoneReason.noLyrics);

      rig.sidecar.byPath['/m/a.flac'] = _lrc;
      await actions().choose(target, LyricsChoice.auto);
      await rig.until(() => rig.status is LyricsFound);

      expect(found().lyrics.lines.single.text, 'local');
      expect(await rig.h.db.watchLyricsPin(target.trackKey).first, isNull);
    });

    for (final (name, from, to) in [
      ('local', LyricsChoice.auto, LyricsChoice.local),
      ('automatic', LyricsChoice.local, LyricsChoice.auto),
    ]) {
      test('the source never flips while choosing $name', () async {
        await show();
        if (from != LyricsChoice.auto) {
          await actions().choose(target, from);
          await rig.settle();
        }
        final values = <LyricsSourceResolution>[];
        final sub = rig.container.listen(
          playingLyricsSourceProvider,
          (_, next) => values.add(next!),
          fireImmediately: true,
        );
        addTearDown(sub.close);

        await actions().choose(target, to);
        await rig.settle();

        expect(values.last.chosen, to);
        // After the first value (before the choice), every value is already
        // the final one: no momentary fallback while the lyrics are re-read.
        for (final v in values.skip(1)) {
          expect(v.effective, to);
          expect(v.hasLocal, isTrue);
          expect(v.status, isA<LyricsFound>());
        }
      });
    }

    test('an unknown stored mode reads as automatic', () async {
      expect(parseLyricsChoice('later'), LyricsChoice.auto);
      expect(parseLyricsChoice(null), LyricsChoice.auto);
    });
  });

  group('while the next song is read', () {
    test('its first record is its own, not the previous song\'s', () async {
      final b = fakeSong('/m/b.flac', title: 'B');
      rig = await createStatusRig(autoFetch: false);
      rig.sidecar.byPath['/m/a.flac'] = _lrc;
      rig.sidecar.gates['/m/b.flac'] = Completer<void>();
      rig.watch();
      await rig.play([song, b]);
      await rig.until(() => rig.status is LyricsFound);
      await actions().choose(target, LyricsChoice.local);
      await rig.until(() => source().chosen == LyricsChoice.local);
      await rig.settle();

      final values = <LyricsSourceResolution?>[];
      final sub = rig.container.listen(
        playingLyricsSourceProvider,
        (_, next) => values.add(next),
      );
      addTearDown(sub.close);
      await rig.player.next();
      await rig.until(() => values.any((v) => v?.status.uri == '/m/b.flac'));

      final first = values.firstWhere((v) => v?.status.uri == '/m/b.flac')!;
      expect(first.status, isA<LyricsReading>());
      expect(first.chosen, LyricsChoice.auto);
      expect(first.hasLocal, isFalse);
      expect(first.effective, LyricsChoice.auto);
      rig.sidecar.gates['/m/b.flac']!.complete();
    });
  });
}
