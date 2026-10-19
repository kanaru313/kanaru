import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/walk_audio_files.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('walk_test'));
  tearDown(() {
    // Restore access so cleanup can descend.
    Process.runSync('chmod', ['-R', 'u+rwx', tmp.path]);
    tmp.deleteSync(recursive: true);
  });

  File touch(String rel, [String content = 'x']) => File('${tmp.path}/$rel')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  Set<String> names(WalkResult r) => {
    for (final f in r.files) f.path.substring(tmp.path.length + 1),
  };

  test('finds audio files recursively with mtime and size', () {
    touch('a.mp3', 'abc');
    touch('sub/deep/b.FLAC');
    touch('notes.txt');

    final result = walkAudioFiles(tmp.path);

    expect(names(result), {'a.mp3', 'sub/deep/b.FLAC'});
    final a = result.files.firstWhere((f) => f.path.endsWith('a.mp3'));
    expect(a.sizeBytes, 3);
    expect(a.mtimeMs, File(a.path).statSync().modified.millisecondsSinceEpoch);
    expect(result.rootMissing, isFalse);
  });

  test(
    'takes symlinks to files, reports broken audio links as unstattable',
    () {
      touch('real.mp3');
      Link('${tmp.path}/link.mp3').createSync('${tmp.path}/real.mp3');
      Link('${tmp.path}/broken.mp3').createSync('${tmp.path}/nowhere.mp3');

      final result = walkAudioFiles(tmp.path);

      expect(names(result), {'real.mp3', 'link.mp3'});
      expect(result.unstattable, ['${tmp.path}/broken.mp3']);
    },
  );

  test(
    'reports an empty subfolder but not the root or a folder with files',
    () {
      touch('full/a.mp3');
      Directory('${tmp.path}/nas').createSync();
      Directory('${tmp.path}/parent/child').createSync(recursive: true);

      final result = walkAudioFiles(tmp.path);

      expect(
        result.emptyDirs,
        unorderedEquals(['${tmp.path}/nas', '${tmp.path}/parent/child']),
      );
      expect(walkAudioFiles('${tmp.path}/full').emptyDirs, isEmpty);
      expect(walkAudioFiles('${tmp.path}/nas').emptyDirs, isEmpty);
    },
  );

  test('does not follow folder symlinks, even loops', () {
    touch('music/a.mp3');
    Link('${tmp.path}/music/loop').createSync(tmp.path);
    Link('${tmp.path}/alias').createSync('${tmp.path}/music');

    final result = walkAudioFiles(tmp.path);

    expect(names(result), {'music/a.mp3'});
  });

  test('excludes a FIFO named like audio', () {
    touch('a.mp3');
    final made = Process.runSync('mkfifo', ['${tmp.path}/pipe.flac']);
    expect(made.exitCode, 0);

    expect(names(walkAudioFiles(tmp.path)), {'a.mp3'});
  });

  test(
    'reports an unreadable folder',
    () {
      touch('ok.mp3');
      touch('locked/hidden.mp3');
      Process.runSync('chmod', ['000', '${tmp.path}/locked']);

      final result = walkAudioFiles(tmp.path);

      expect(names(result), {'ok.mp3'});
      expect(result.unreadableDirs, ['${tmp.path}/locked']);
    },
    skip: Process.runSync('id', ['-u']).stdout.toString().trim() == '0'
        ? 'root can read everything'
        : false,
  );

  test('a missing root is reported, not thrown', () {
    final result = walkAudioFiles('${tmp.path}/absent');

    expect(result.rootMissing, isTrue);
    expect(result.files, isEmpty);
  });

  test('works through an isolate', () async {
    touch('a.mp3');

    final result = await walkAudioFilesInIsolate(tmp.path);

    expect(names(result), {'a.mp3'});
  });
}
