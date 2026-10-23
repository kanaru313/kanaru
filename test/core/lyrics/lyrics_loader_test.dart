import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/lyrics_loader.dart';

import 'fake_lyrics_readers.dart';

void main() {
  const path = '/m/song.mp3';
  late FakeEmbeddedLyricsReader embedded;
  late FakeLrcSidecarReader sidecar;

  setUp(() {
    embedded = FakeEmbeddedLyricsReader();
    sidecar = FakeLrcSidecarReader();
  });

  Future<Lyrics?> load({bool preferEmbedded = true}) => loadLyrics(
    path,
    preferEmbedded: preferEmbedded,
    embedded: embedded,
    sidecar: sidecar,
  );

  test('prefer embedded: tags first, the .lrc file is not read', () async {
    embedded.byPath[path] = (text: 'From tags', synced: const []);
    sidecar.byPath[path] = '[00:01.00]From file';

    final lyrics = (await load())!;
    expect(lyrics.source, LyricsSource.embedded);
    expect(lyrics.synced, isFalse);
    expect(lyrics.lines.single.text, 'From tags');
    expect(sidecar.reads, isEmpty);
  });

  test('prefer the file: .lrc first, tags not read', () async {
    embedded.byPath[path] = (text: 'From tags', synced: const []);
    sidecar.byPath[path] = '[00:01.00]From file';

    final lyrics = (await load(preferEmbedded: false))!;
    expect(lyrics.source, LyricsSource.sidecar);
    expect(lyrics.synced, isTrue);
    expect(embedded.reads, isEmpty);
  });

  test('the other source is used when the preferred one has nothing', () async {
    sidecar.byPath[path] = 'From file';
    expect((await load())!.source, LyricsSource.sidecar);

    sidecar.byPath.clear();
    embedded.byPath[path] = (text: 'From tags', synced: const []);
    expect((await load(preferEmbedded: false))!.source, LyricsSource.embedded);
  });

  test('blank lyrics count as none', () async {
    embedded.byPath[path] = (text: '  \n', synced: const []);
    sidecar.byPath[path] = 'From file';
    expect((await load())!.source, LyricsSource.sidecar);
  });

  test('SYLT lines win over the tag text', () async {
    embedded.byPath[path] = (
      text: 'Plain',
      synced: const [LyricLine(Duration(seconds: 1), 'Timed')],
    );
    final lyrics = (await load())!;
    expect(lyrics.synced, isTrue);
    expect(lyrics.lines.single.text, 'Timed');
  });

  test('LRC text in a tag is synced', () async {
    embedded.byPath[path] = (text: '[00:02.00]Tagged LRC', synced: const []);
    final lyrics = (await load())!;
    expect(lyrics.synced, isTrue);
    expect(lyrics.lines.single.time, const Duration(seconds: 2));
  });

  test('a failing source counts as absent', () async {
    embedded.failing.add(path);
    sidecar.byPath[path] = 'From file';
    expect((await load())!.source, LyricsSource.sidecar);

    sidecar.failing.add(path);
    expect(await load(), isNull);
  });

  test('neither source gives null', () async {
    expect(await load(), isNull);
    expect(embedded.reads, [path]);
    expect(sidecar.reads, [path]);
  });
}
