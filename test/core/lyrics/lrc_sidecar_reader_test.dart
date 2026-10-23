import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';

void main() {
  late Directory dir;
  const reader = FileLrcSidecarReader();

  setUp(() => dir = Directory.systemTemp.createTempSync('kanaru_lrc_'));
  tearDown(() => dir.deleteSync(recursive: true));

  String audio(String name) => '${dir.path}/$name';

  test('candidates swap the extension for .lrc then .LRC', () {
    expect(lrcCandidates('/m/a.b/song.flac'), [
      '/m/a.b/song.lrc',
      '/m/a.b/song.LRC',
    ]);
    expect(lrcCandidates('/m/a.b/song'), [
      '/m/a.b/song.lrc',
      '/m/a.b/song.LRC',
    ]);
    expect(lrcCandidates('/m/.hidden'), ['/m/.hidden.lrc', '/m/.hidden.LRC']);
  });

  test('reads <name>.lrc', () async {
    File(audio('song.lrc')).writeAsStringSync('[00:01.00]Hi');
    expect(await reader.read(audio('song.mp3')), '[00:01.00]Hi');
  });

  test('reads <name>.LRC', () async {
    File(audio('song.LRC')).writeAsStringSync('Upper');
    expect(await reader.read(audio('song.mp3')), 'Upper');
  });

  test('decodes a UTF-16 file', () async {
    File(audio('song.lrc')).writeAsBytesSync([0xFF, 0xFE, 0x41, 0x00]);
    expect(await reader.read(audio('song.mp3')), 'A');
  });

  test('no file, or a folder of that name, gives null', () async {
    expect(await reader.read(audio('song.mp3')), isNull);
    Directory(audio('song.lrc')).createSync();
    expect(await reader.read(audio('song.mp3')), isNull);
  });

  test('a file over the cap gives null', () async {
    File(audio('song.lrc'))
        .writeAsBytesSync(List.filled(lrcMaxBytes + 1, 0x41));
    expect(await reader.read(audio('song.mp3')), isNull);
  });

  test('a FIFO of that name is never opened', () async {
    final fifo = audio('song.lrc');
    final made = Process.runSync('mkfifo', [fifo]);
    expect(made.exitCode, 0);
    expect(
      await reader.read(audio('song.mp3')).timeout(const Duration(seconds: 5)),
      isNull,
    );
  }, skip: Platform.isLinux ? false : 'mkfifo is used on Linux only');
}
