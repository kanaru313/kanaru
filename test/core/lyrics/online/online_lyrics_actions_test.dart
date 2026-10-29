import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lrc_sidecar_writer.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_actions.dart';
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

  Future<void> show({bool writeLrc = false, bool autoFetch = true}) async {
    rig = await createStatusRig(writeLrc: writeLrc, autoFetch: autoFetch);
    rig.watch();
    await rig.play([song]);
  }

  group('pick and unpin', () {
    test('a pick beats embedded lyrics; unpin shows them again', () async {
      rig = await createStatusRig();
      rig.sidecar.byPath['/m/a.flac'] = _lrc;
      rig.watch();
      await rig.play([song]);
      await rig.until(() => rig.status is LyricsFound);
      expect(found().origin, isNull);

      await actions().pick(target, picked);
      await rig.until(() => found().origin != null);
      expect(found().origin!.pinned, isTrue);
      expect(found().origin!.remoteId, 'pick');
      expect(found().lyrics.lines.single.text, 'picked');

      await actions().unpin(target);
      await rig.until(() => found().origin == null);
      expect(found().lyrics.lines.single.text, 'local');
      expect(rig.requests, 0);
    });

    test('picking a rejected record pins it and clears the reject', () async {
      await show();
      rig.fake.lookupResult = fakeCandidate(remoteId: 'x');
      await rig.until(() => rig.status is LyricsFound);
      await actions().skip(target, found().origin!);
      await rig.until(() => rig.status is LyricsNone);
      expect(await rig.h.db.rejectedRemoteIds(target.cacheKey), {
        ('fake', 'x'),
      });

      await actions().pick(target, fakeCandidate(remoteId: 'x'));
      await rig.until(() => rig.status is LyricsFound);

      expect(found().origin!.remoteId, 'x');
      expect(found().origin!.pinned, isTrue);
      expect(await rig.h.db.rejectedRemoteIds(target.cacheKey), isEmpty);

      // After unpin, an automatic lookup may find the record again.
      final calls = rig.fake.lookupCalls;
      await actions().unpin(target);
      await rig.until(() => rig.fake.lookupCalls > calls);
      await rig.until(() => rig.status is LyricsFound);
      expect(found().origin!.remoteId, 'x');
    });

    test('a pick without a body is refused', () async {
      await show();
      await expectLater(
        actions().pick(target, fakeCandidate(body: null)),
        throwsArgumentError,
      );
    });

    test('write .lrc on: written once, after the pin exists', () async {
      await show(writeLrc: true, autoFetch: false);
      Object? pinAtWrite;
      rig.writer.onWrite = () async {
        pinAtWrite = await rig.h.db.watchLyricsPin(target.trackKey).first;
      };

      final result = await actions().pick(target, picked);

      expect(result, LrcWriteResult.written);
      expect(rig.writer.writes, hasLength(1));
      expect(rig.writer.writes.single.$1, '/m/a.flac');
      expect(pinAtWrite, isNotNull);
    });

    test('write .lrc off: the writer is not called', () async {
      await show(autoFetch: false);
      expect(await actions().pick(target, picked), isNull);
      expect(rig.writer.writes, isEmpty);
    });

    test('a failed write keeps the pinned lyrics', () async {
      await show(writeLrc: true, autoFetch: false);
      rig.writer.result = LrcWriteResult.failed;

      expect(await actions().pick(target, picked), LrcWriteResult.failed);
      await rig.until(() => rig.status is LyricsFound);
      expect(found().origin!.pinned, isTrue);
    });

    test('a song outside the file system is never written', () async {
      rig = await createStatusRig(writeLrc: true);
      final remote = LyricsTarget.fromTrack(fakeSong('https://x.test/a.mp3'));

      expect(await actions().pick(remote, picked), isNull);
      expect(rig.writer.writes, isEmpty);
    });
  });

  group('skip and search again', () {
    test('Not these lyrics hides the match and sends nothing', () async {
      await show();
      rig.fake.lookupResult = fakeCandidate(remoteId: 'x');
      await rig.until(() => rig.status is LyricsFound);
      final requests = rig.requests;

      await actions().skip(target, found().origin!);
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();

      expect((rig.status as LyricsNone).reason, LyricsNoneReason.skipped);
      expect(rig.requests, requests);
    });

    test('a skip does not hide the song\'s own lyrics', () async {
      rig = await createStatusRig();
      rig.sidecar.byPath['/m/a.flac'] = _lrc;
      rig.watch();
      await rig.play([song]);
      await actions().skip(
        target,
        const OnlineLyricsOrigin(
          providerId: 'fake',
          remoteId: 'x',
          pinned: false,
        ),
      );
      await rig.settle();

      expect(found().origin, isNull);
      expect(found().lyrics.lines.single.text, 'local');
      expect(rig.requests, 0);
    });

    test(
      'Search again drops the skip and excludes the rejected match',
      () async {
        await show();
        rig.fake.lookupResult = fakeCandidate(remoteId: 'x');
        await rig.until(() => rig.status is LyricsFound);
        await actions().skip(target, found().origin!);
        await rig.until(() => rig.status is LyricsNone);

        rig.fake.searchResult = [
          fakeCandidate(
            remoteId: 'y',
            body: const LyricsBody(syncedLrc: '[00:01.00] next'),
          ),
        ];
        await actions().searchAgain(target);
        await rig.until(() => rig.status is LyricsFound);

        expect(found().origin!.remoteId, 'y');
        expect(await rig.h.db.rejectedRemoteIds(target.cacheKey), {
          ('fake', 'x'),
        });
      },
    );

    test('Search again with only the rejected match left finds none', () async {
      await show();
      rig.fake.lookupResult = fakeCandidate(remoteId: 'x');
      await rig.until(() => rig.status is LyricsFound);
      await actions().skip(target, found().origin!);
      await actions().searchAgain(target);
      await rig.until(
        () => rig.status is LyricsNone && rig.fake.lookupCalls == 2,
      );
      await rig.settle();

      expect((rig.status as LyricsNone).reason, LyricsNoneReason.notFound);
    });

    test('Retry and Search again send nothing without consent', () async {
      rig = await createStatusRig(
        autoFetch: false,
        autoConsent: false,
        manualConsent: false,
      );
      await actions().retry(target);
      await actions().searchAgain(target);

      expect(rig.requests, 0);
    });
  });
}
