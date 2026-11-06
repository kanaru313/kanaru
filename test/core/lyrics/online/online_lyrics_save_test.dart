import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';
import 'package:kanaru/core/lyrics/online/lrc_sidecar_writer.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_actions.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_source_provider.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_content_hash.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_file_trash.dart';
import 'fake_lyrics_provider.dart';
import 'status_test_rig.dart';

const _body = LyricsBody(syncedLrc: '[00:02.00] picked\r\n[00:03.00] more\n');

void main() {
  late StatusRig rig;
  final song = fakeSong('/m/a.flac');
  final target = LyricsTarget.fromTrack(song);
  final picked = fakeCandidate(remoteId: 'pick', body: _body);
  const origin = OnlineLyricsOrigin(
    providerId: 'fake',
    remoteId: 'pick',
    pinned: true,
  );

  bool foundWithOrigin({required bool hasOrigin}) => switch (rig.status) {
    LyricsFound(:final origin) => (origin != null) == hasOrigin,
    _ => false,
  };

  OnlineLyricsActions actions() =>
      rig.container.read(onlineLyricsActionsProvider);
  Future<LyricsChoice?> choice() async => parseLyricsChoice(
    (await rig.h.db.watchLyricsPin(target.trackKey).first)?.mode,
  );

  Future<void> show() async {
    rig = await createStatusRig(autoFetch: false);
    rig.watch();
    await rig.play([song]);
    await rig.settle();
  }

  test('saving a pick writes the file and keeps the pick', () async {
    await show();
    await actions().pick(target, picked);
    rig.sidecar.byPath['/m/a.flac'] = _body.syncedLrc!;

    final outcome = await actions().save(target, origin);

    expect(outcome, (result: LrcWriteResult.written, kept: null));
    expect(rig.writer.writes.single.$1, '/m/a.flac');
    expect(rig.writer.replaces, [false]);
    final pin = await rig.h.db.watchLyricsPin(target.trackKey).first;
    expect(pin!.mode, 'online');
    expect(pin.remoteId, 'pick');
    await rig.until(() => foundWithOrigin(hasOrigin: true));
  });

  test('saving twice reports identical, and rejecting drops the pin', () async {
    await show();
    await actions().pick(target, picked);
    rig.sidecar.byPath['/m/a.flac'] = _body.syncedLrc!;
    await actions().save(target, origin);
    await rig.until(() => rig.status is LyricsFound);
    rig.writer.result = LrcWriteResult.identical;

    final again = await actions().save(target, origin);
    expect(again, (result: LrcWriteResult.identical, kept: null));

    await actions().reject(target, origin, (rig.status as LyricsFound).lyrics);
    expect(await rig.h.db.watchLyricsPin(target.trackKey).first, isNull);
    await rig.until(() => foundWithOrigin(hasOrigin: false));
  });

  test('saving an automatic match leaves no choice', () async {
    rig = await createStatusRig();
    rig.fake.lookupResult = fakeCandidate(remoteId: 'auto', body: _body);
    rig.watch();
    await rig.play([song]);
    await rig.until(() => rig.status is LyricsFound);
    final auto = (rig.status as LyricsFound).origin!;
    expect(auto.pinned, isFalse);
    rig.sidecar.byPath['/m/a.flac'] = _body.syncedLrc!;

    final outcome = await actions().save(target, auto, replace: true);

    expect(outcome.result, LrcWriteResult.written);
    expect(outcome.kept, isNull);
    expect(rig.writer.replaces, [true]);
    expect(await choice(), isNull);
  });

  test('identical keeps the pick as well', () async {
    await show();
    await actions().pick(target, picked);
    rig.writer.result = LrcWriteResult.identical;
    rig.sidecar.byPath['/m/a.flac'] = _body.syncedLrc!;

    final outcome = await actions().save(target, origin);

    expect(outcome, (result: LrcWriteResult.identical, kept: null));
    expect(await choice(), LyricsChoice.online);
  });

  test('a refusal keeps the pick and reports the result', () async {
    await show();
    await actions().pick(target, picked);
    for (final result in [
      LrcWriteResult.exists,
      LrcWriteResult.failed,
      LrcWriteResult.trashFailed,
      LrcWriteResult.trashedNotWritten,
    ]) {
      rig.writer.result = result;

      final outcome = await actions().save(target, origin);

      expect(outcome, (result: result, kept: null));
    }
    expect(await choice(), LyricsChoice.online);
  });

  test('a partial save reads the song\'s own lyrics again', () async {
    for (final result in [
      LrcWriteResult.trashedNotWritten,
      LrcWriteResult.trashTimedOut,
    ]) {
      rig = await createStatusRig(autoFetch: false);
      rig.watch();
      rig.sidecar.byPath['/m/a.flac'] = '[00:01.00] old';
      await rig.play([song]);
      await rig.until(
        () => rig.container.read(playingLyricsSourceProvider)?.hasLocal == true,
      );
      await actions().pick(target, picked);
      // The old file went to the trash and the new one was not written.
      rig.sidecar.byPath.remove('/m/a.flac');
      rig.writer.result = result;

      final outcome = await actions().save(target, origin);

      expect(outcome, (result: result, kept: null));
      await rig.until(
        () =>
            rig.container.read(playingLyricsSourceProvider)?.hasLocal == false,
      );
      rig.unwatch();
    }
  });

  test('stored text that is gone gives no result and writes nothing', () async {
    await show();

    final outcome = await actions().save(
      target,
      const OnlineLyricsOrigin(
        providerId: 'fake',
        remoteId: 'unknown',
        pinned: false,
      ),
    );

    expect(outcome, (result: null, kept: null));
    expect(rig.writer.writes, isEmpty);
  });

  test('two saves of one song at once make one write', () async {
    await show();
    await actions().pick(target, picked);
    rig.sidecar.byPath['/m/a.flac'] = _body.syncedLrc!;
    final gate = Completer<void>();
    rig.writer.onWrite = () => gate.future;

    final first = actions().save(target, origin);
    await pumpEventQueue();
    expect(actions().isSaving(target.trackKey), isTrue);
    final second = await actions().save(target, origin);
    gate.complete();
    final done = await first;

    expect(second, (result: null, kept: null));
    expect(done.result, LrcWriteResult.written);
    expect(rig.writer.writes, hasLength(1));
    expect(actions().isSaving(target.trackKey), isFalse);
  });

  test('a song that is not a local file is outsideLibrary', () async {
    await show();
    await actions().pick(target, picked);
    final remote = LyricsTarget(trackKey: target.trackKey, query: target.query);

    final outcome = await actions().save(remote, origin);

    expect(outcome.result, LrcWriteResult.outsideLibrary);
    expect(rig.writer.writes, isEmpty);
  });

  test('tag lyrics preferred: a pinned save gives no reason', () async {
    rig = await createStatusRig(autoFetch: false);
    rig.container
        .read(settingsProvider.notifier)
        .setPlayback(
          rig.container
              .read(settingsProvider)
              .playback
              .copyWith(preferEmbeddedLyrics: true),
        );
    rig.embedded.byPath['/m/a.flac'] = (text: 'tag words', synced: const []);
    rig.watch();
    await rig.play([song]);
    await rig.settle();
    await actions().pick(target, picked);
    rig.sidecar.byPath['/m/a.flac'] = _body.syncedLrc!;

    final outcome = await actions().save(target, origin);

    // The pick is the saved record and keeps showing: no reason to give.
    expect(outcome, (result: LrcWriteResult.written, kept: null));
    expect(await choice(), LyricsChoice.online);
  });

  test('another file read after saving an automatic match says so', () async {
    rig = await createStatusRig();
    rig.fake.lookupResult = fakeCandidate(remoteId: 'auto', body: _body);
    rig.watch();
    await rig.play([song]);
    await rig.until(() => rig.status is LyricsFound);
    final auto = (rig.status as LyricsFound).origin!;
    // The file Kanaru reads holds other words than the saved ones.
    rig.sidecar.byPath['/m/a.flac'] = '[00:01.00] different';

    final outcome = await actions().save(target, auto);

    expect(outcome, (
      result: LrcWriteResult.written,
      kept: LyricsChoiceKept.otherFile,
    ));
  });

  test('another file being read: a pinned save gives no reason', () async {
    await show();
    await actions().pick(target, picked);
    rig.sidecar.byPath['/m/a.flac'] = '[00:01.00] different';

    final outcome = await actions().save(target, origin);

    expect(outcome, (result: LrcWriteResult.written, kept: null));
    expect(await choice(), LyricsChoice.online);
  });

  group('with real files', () {
    late Directory tmp;
    late String path;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('kanaru_save_');
      final library = '${tmp.resolveSymbolicLinksSync()}/library';
      Directory(library).createSync();
      path = '$library/a.flac';
      File(path).writeAsBytesSync([1, 2, 3]);
      addTearDown(() => tmp.deleteSync(recursive: true));
    });

    test('the saved file shows the same lyrics, hash included', () async {
      final writer = FileLrcSidecarWriter(
        libraryRoots: () async => [File(path).parent.path],
        excludedFolders: () async => const [],
        trash: FakeFileTrash('${tmp.path}/trash'),
      );
      rig = await createStatusRig(autoFetch: false);
      // The real writer, and the real reader for the file it wrote.
      rig.writer.delegate = writer;
      rig.sidecar.delegate = const FileLrcSidecarReader();
      final realSong = fakeSong(path);
      final realTarget = LyricsTarget.fromTrack(realSong);
      rig.watch();
      await rig.play([realSong]);
      await rig.settle();
      await actions().pick(realTarget, picked);
      await rig.until(() => foundWithOrigin(hasOrigin: true));
      final before = lyricsContentHashOf((rig.status as LyricsFound).lyrics);

      final outcome = await actions().save(realTarget, origin);

      expect(outcome, (result: LrcWriteResult.written, kept: null));
      expect(File('${tmp.path}/library/a.lrc').existsSync(), isTrue);
      // The pick keeps showing; choosing the file reads the saved .lrc.
      await actions().choose(realTarget, LyricsChoice.local);
      await rig.until(() => foundWithOrigin(hasOrigin: false));
      final after = lyricsContentHashOf((rig.status as LyricsFound).lyrics);
      expect(after, before);
    });
  });
}
