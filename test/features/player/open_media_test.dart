import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/format_duration.dart';
import 'package:kanaru/features/player/open_media.dart';

void main() {
  test('recognizes audio extensions in any case', () {
    expect(isAudioFile('/a/song.FLAC'), isTrue);
    expect(isAudioFile('/a/song.opus'), isTrue);
    expect(isAudioFile('/a/cover.jpg'), isFalse);
    expect(isAudioFile('/a/flac'), isFalse);
  });

  test('scans a folder recursively, audio only, sorted by path', () async {
    final root = await Directory.systemTemp.createTemp('kanaru_scan');
    addTearDown(() => root.delete(recursive: true));
    for (final path in [
      'b.mp3',
      'a.flac',
      'cover.jpg',
      'disc 2/01 intro.m4a',
      'disc 2/notes.txt',
    ]) {
      await File('${root.path}/$path').create(recursive: true);
    }

    final tracks = await scanFolder(root.path);

    expect(tracks.map((t) => t.uri.substring(root.path.length + 1)), [
      'a.flac',
      'b.mp3',
      'disc 2/01 intro.m4a',
    ]);
    expect(tracks.last.title, '01 intro');
  });

  test('skips unreadable folders and follows file links', () async {
    final root = await Directory.systemTemp.createTemp('kanaru_scan');
    final locked = Directory('${root.path}/locked');
    addTearDown(() async {
      await Process.run('chmod', ['755', locked.path]);
      await root.delete(recursive: true);
    });
    await File('${locked.path}/hidden.mp3').create(recursive: true);
    await File('${root.path}/real.flac').create();
    await Link('${root.path}/linked.flac').create('${root.path}/real.flac');
    await Link('${root.path}/loop').create(root.path);
    await Process.run('chmod', ['000', locked.path]);

    final tracks = await scanFolder(root.path);

    expect(tracks.map((t) => t.title), ['linked', 'real']);
  });

  test('formats durations', () {
    expect(formatDuration(Duration.zero), '0:00');
    expect(formatDuration(const Duration(minutes: 3, seconds: 5)), '3:05');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });
}
