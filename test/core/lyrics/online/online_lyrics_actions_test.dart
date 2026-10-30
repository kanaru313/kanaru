import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_actions.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_entries.dart';
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

  Future<void> show({bool autoFetch = true, bool local = false}) async {
    rig = await createStatusRig(autoFetch: autoFetch);
    if (local) rig.sidecar.byPath['/m/a.flac'] = _lrc;
    rig.watch();
    await rig.play([song]);
  }

  group('pick', () {
    test('beats the song\'s own lyrics and writes no file', () async {
      await show(autoFetch: false, local: true);
      await rig.until(() => rig.status is LyricsFound);
      expect(found().origin, isNull);

      await actions().pick(target, picked);
      await rig.until(() => found().origin != null);

      expect(found().origin!.pinned, isTrue);
      expect(found().origin!.remoteId, 'pick');
      expect(found().lyrics.lines.single.text, 'picked');
      expect(rig.writer.writes, isEmpty);
      final pin = await rig.h.db.watchLyricsPin(target.trackKey).first;
      expect(pin!.mode, 'online');
      expect(rig.requests, 0);
    });

    test('a pick without a body is refused', () async {
      await show();
      await expectLater(
        actions().pick(target, fakeCandidate(body: null)),
        throwsArgumentError,
      );
    });

    test('picking a rejected record pins it and clears the reject', () async {
      await show();
      rig.fake.lookupResult = fakeCandidate(remoteId: 'x');
      await rig.until(() => rig.status is LyricsFound);
      await rig.settle();
      final shown = found();
      await actions().reject(target, shown.origin!, shown.lyrics);
      await rig.until(() => rig.status is LyricsNone);
      expect((await rig.h.db.rejectedMatches(target.cacheKey)).ids, {
        ('fake', 'x'),
      });

      await actions().pick(target, fakeCandidate(remoteId: 'x'));
      await rig.until(() => rig.status is LyricsFound);

      expect(found().origin!.remoteId, 'x');
      expect(found().origin!.pinned, isTrue);
      final matches = await rig.h.db.rejectedMatches(target.cacheKey);
      expect(matches.ids, isEmpty);
      expect(matches.hashes, isEmpty);
    });

    test(
      'a copy of a rejected text is no longer rejected once picked',
      () async {
        await show(autoFetch: false);
        await rig.settle();
        await actions().reject(
          target,
          const OnlineLyricsOrigin(
            providerId: 'fake',
            remoteId: 'old',
            pinned: false,
          ),
          parseStoredLyrics(synced: '[00:01.00] hello')!,
        );
        expect(
          (await rig.h.db.rejectedMatches(target.cacheKey)).hashes,
          hasLength(1),
        );

        await actions().pick(target, fakeCandidate(remoteId: 'copy'));

        expect(
          (await rig.h.db.rejectedMatches(target.cacheKey)).hashes,
          isEmpty,
        );
      },
    );
  });

  group('keep', () {
    test('turns an automatic match into the song\'s pick', () async {
      await show();
      rig.fake.lookupResult = fakeCandidate(remoteId: 'x');
      await rig.until(() => rig.status is LyricsFound);
      await rig.settle();
      expect(found().origin!.pinned, isFalse);
      final text = found().lyrics;

      await actions().keep(target, found().origin!);
      await rig.until(() => found().origin!.pinned);

      expect(found().origin!.remoteId, 'x');
      expect(found().lyrics.lines.first.text, text.lines.first.text);
      final pin = await rig.h.db.watchLyricsPin(target.trackKey).first;
      expect(pin!.mode, 'online');
    });

    test('does nothing when the text is gone from the cache', () async {
      await show(autoFetch: false);
      await rig.settle();

      await actions().keep(
        target,
        const OnlineLyricsOrigin(
          providerId: 'fake',
          remoteId: 'gone',
          pinned: false,
        ),
      );

      expect(await rig.h.db.watchLyricsPin(target.trackKey).first, isNull);
    });
  });

  test('Retry sends nothing without consent', () async {
    rig = await createStatusRig(
      autoFetch: false,
      autoConsent: false,
      manualConsent: false,
    );
    await actions().retry(target);

    expect(rig.requests, 0);
  });
}
