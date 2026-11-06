import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
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

  Future<void> show({required bool local}) async {
    rig = await createStatusRig(autoFetch: false);
    if (local) rig.sidecar.byPath['/m/a.flac'] = _lrc;
    rig.watch();
    await rig.play([song]);
    await rig.until(() => rig.status is! LyricsReading);
    await rig.settle();
  }

  Future<void> turnOff() async {
    await actions().choose(target, LyricsChoice.off);
    await rig.until(() => rig.status is LyricsNone);
  }

  test('local with a pick: off then on restores local, pick kept', () async {
    await show(local: true);
    await actions().pick(target, picked);
    await rig.until(() => found().origin != null);
    await actions().choose(target, LyricsChoice.local);
    await rig.until(() => found().origin == null);

    await turnOff();
    final off = await rig.h.db.watchLyricsPin(target.trackKey).first;
    expect(off!.mode, 'off:local');

    await actions().turnOn(target);
    await rig.until(() => rig.status is LyricsFound);

    expect(found().lyrics.lines.single.text, 'local');
    final pin = await rig.h.db.watchLyricsPin(target.trackKey).first;
    expect(pin!.mode, 'local');
    expect(pin.remoteId, 'pick');
    expect(
      rig.container.read(playingLyricsSourceProvider)!.effective,
      LyricsChoice.local,
    );
  });

  test('pick only: off then on restores the pick', () async {
    await show(local: false);
    await actions().pick(target, picked);
    await rig.until(() => rig.status is LyricsFound);

    await turnOff();
    expect((await rig.h.db.watchLyricsPin(target.trackKey).first)!.mode, 'off');

    await actions().turnOn(target);
    await rig.until(() => rig.status is LyricsFound);

    expect(found().origin!.remoteId, 'pick');
    expect(
      (await rig.h.db.watchLyricsPin(target.trackKey).first)!.mode,
      'online',
    );
  });

  test('nothing stored: off then on removes the row', () async {
    await show(local: true);

    await turnOff();
    await actions().turnOn(target);
    await rig.until(() => rig.status is LyricsFound);

    expect(await rig.h.db.watchLyricsPin(target.trackKey).first, isNull);
  });

  test('turn on does nothing while lyrics are not off', () async {
    await show(local: true);
    await actions().choose(target, LyricsChoice.local);
    await rig.settle();

    final before = await rig.h.db.watchLyricsPin(target.trackKey).first;

    await actions().turnOn(target);

    final after = await rig.h.db.watchLyricsPin(target.trackKey).first;
    expect(after!.mode, 'local');
    expect(after.pinnedAt, before!.pinnedAt);
  });
}
