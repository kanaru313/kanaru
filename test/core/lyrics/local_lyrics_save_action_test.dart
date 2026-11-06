import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/embedded_lyrics_reader.dart';
import 'package:kanaru/core/lyrics/local_lyrics_save_action.dart';
import 'package:kanaru/core/lyrics/lrc_parser.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/online/lrc_sidecar_writer.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_save_action.dart';
import 'package:kanaru/core/lyrics/playing_local_lyrics_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_lyrics_readers.dart';
import 'online/status_test_rig.dart';

const _path = '/m/a.flac';

final _save = Provider(
  (ref) =>
      (LyricsTarget target, {bool replace = false}) =>
          saveLocalLyricsAsLrc(ref, target, replace: replace),
);

void main() {
  late FakeEmbeddedLyricsReader reader;
  late FakeLrcSidecarWriter writer;
  late ProviderContainer container;
  var localBuilds = 0;
  final target = LyricsTarget.fromFields(uri: _path, title: 'T', artist: 'A');

  void build({bool preferEmbedded = false}) {
    localBuilds = 0;
    reader = FakeEmbeddedLyricsReader();
    writer = FakeLrcSidecarWriter();
    container = ProviderContainer(
      overrides: [
        playingLocalLyricsProvider.overrideWith((ref) async {
          localBuilds++;
          return null;
        }),
        embeddedLyricsReaderProvider.overrideWithValue(reader),
        lrcSidecarWriterProvider.overrideWithValue(writer),
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            playback: PlaybackPrefs(preferEmbeddedLyrics: preferEmbedded),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  Future<LyricsSaveOutcome> save({bool replace = false}) =>
      container.read(_save)(target, replace: replace);

  setUp(build);

  test('saves the SYLT lines as shown, not the text', () async {
    reader.byPath[_path] = (
      text: 'plain words',
      synced: const [
        LyricLine(Duration(seconds: 1, milliseconds: 20), 'one'),
        LyricLine(Duration(seconds: 3), 'two'),
      ],
    );

    final outcome = await save();

    expect(outcome, (result: LrcWriteResult.written, kept: null));
    expect(writer.writes.single.$1, _path);
    expect(writer.writes.single.$2.syncedLrc, '[00:01.020]one\n[00:03.000]two');
    expect(writer.writes.single.$2.plain, isNull);
  });

  test('LRC text in the tags is saved as the lines that show', () async {
    reader.byPath[_path] = (
      text: '[00:05.5] hi\n[00:07] bye',
      synced: const [],
    );

    await save();

    final saved = writer.writes.single.$2.syncedLrc!;
    final shown = parseLyricsText(
      '[00:05.5] hi\n[00:07] bye',
      LyricsSource.embedded,
    );
    expect(parseLyricsText(saved, LyricsSource.sidecar)!.lines, shown!.lines);
  });

  test('plain lyrics are saved as plain text', () async {
    reader.byPath[_path] = (text: 'line one\nline two', synced: const []);

    await save();

    expect(writer.writes.single.$2.plain, 'line one\nline two');
    expect(writer.writes.single.$2.syncedLrc, isNull);
  });

  test('tags without lyrics write nothing', () async {
    reader.byPath[_path] = (text: null, synced: const []);

    expect(await save(), (result: null, kept: null));
    expect(writer.writes, isEmpty);
  });

  test('an unreadable tag counts as no lyrics', () async {
    reader.failing.add(_path);

    expect(await save(), (result: LrcWriteResult.failed, kept: null));
    expect(writer.writes, isEmpty);
  });

  for (final result in [LrcWriteResult.written, LrcWriteResult.identical]) {
    test('$result makes the song read its own lyrics again', () async {
      reader.byPath[_path] = (text: 'words', synced: const []);
      writer.result = result;
      final sub = container.listen(playingLocalLyricsProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(playingLocalLyricsProvider.future);
      expect(localBuilds, 1);

      await save();
      await container.read(playingLocalLyricsProvider.future);

      expect(localBuilds, 2);
    });
  }

  test('a failed write does not read the lyrics again', () async {
    reader.byPath[_path] = (text: 'words', synced: const []);
    writer.result = LrcWriteResult.failed;
    final sub = container.listen(playingLocalLyricsProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(playingLocalLyricsProvider.future);

    await save();
    await container.read(playingLocalLyricsProvider.future);

    expect(localBuilds, 1);
  });

  test('a song outside the library has no path to write', () async {
    final remote = LyricsTarget.fromFields(
      uri: 'https://x.test/a.mp3',
      title: 'T',
      artist: 'A',
    );

    final outcome = await container.read(_save)(remote);

    expect(outcome.result, LrcWriteResult.outsideLibrary);
    expect(writer.writes, isEmpty);
  });

  for (final result in [
    LrcWriteResult.exists,
    LrcWriteResult.identical,
    LrcWriteResult.outsideLibrary,
  ]) {
    test('passes $result through', () async {
      reader.byPath[_path] = (text: 'words', synced: const []);
      writer.result = result;

      expect((await save()).result, result);
      expect(writer.replaces, [false]);
    });
  }

  test('replace is passed to the writer', () async {
    reader.byPath[_path] = (text: 'words', synced: const []);

    await save(replace: true);

    expect(writer.replaces, [true]);
  });

  test('prefer embedded says the tags still show', () async {
    build(preferEmbedded: true);
    reader.byPath[_path] = (text: 'words', synced: const []);

    expect(await save(), (
      result: LrcWriteResult.written,
      kept: LyricsChoiceKept.tagPreferred,
    ));
  });
}
