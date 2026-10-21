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

  group('names that are not valid UTF-8', () {
    /// Creates `<dir>/caf\xe9.mp3` (latin-1 e-acute, invalid UTF-8) through
    /// the shell, since Dart encodes every path it is given as UTF-8.
    void touchLatin1(String dir) {
      Directory('${tmp.path}/$dir').createSync(recursive: true);
      final result = Process.runSync('bash', [
        '-c',
        r'touch "$(printf "caf\xe9.mp3")"',
      ], workingDirectory: '${tmp.path}/$dir');
      expect(result.exitCode, 0, reason: '${result.stderr}');
    }

    test('are counted, with their folder, and keep rows via unstattable', () {
      touch('ok.mp3');
      touchLatin1('sub');
      touchLatin1('sub2');

      final result = walkAudioFiles(tmp.path);

      expect(names(result), {'ok.mp3'});
      expect(result.undecodableNames, 2);
      expect(result.undecodableSampleDirs.toSet(), {
        '${tmp.path}/sub',
        '${tmp.path}/sub2',
      });
      expect(result.unstattable, hasLength(2));
    });

    test('a folder name that is not UTF-8 is counted, with its parent', () {
      touch('ok.mp3');
      Directory('${tmp.path}/albums').createSync();
      final made = Process.runSync('bash', [
        '-c',
        r'mkdir "$(printf "caf\xe9")" && touch "$(printf "caf\xe9")/in.mp3"',
      ], workingDirectory: '${tmp.path}/albums');
      expect(made.exitCode, 0, reason: '${made.stderr}');

      final result = walkAudioFiles(tmp.path);

      expect(names(result), {'ok.mp3'});
      expect(result.undecodableNames, 1);
      expect(result.undecodableSampleDirs, ['${tmp.path}/albums']);
      expect(result.unreadableDirs, hasLength(1));
    });

    test('a name that really holds U+FFFD is a normal file, once', () {
      touch('bad\u{FFFD}name.mp3');
      final result = walkAudioFiles(tmp.path);
      expect(names(result), {'bad\u{FFFD}name.mp3'});
      expect(result.undecodableNames, 0);
    });

    test('several raw names that decode alike give one entry at most', () {
      final made = Process.runSync('bash', [
        '-c',
        r'touch "$(printf "a\xe9.mp3")" "$(printf "a\xe8.mp3")"',
      ], workingDirectory: tmp.path);
      expect(made.exitCode, 0);
      final result = walkAudioFiles(tmp.path);
      expect(result.files, isEmpty);
      expect(result.undecodableNames, 2);
    });

    test('samples stop at three folders', () {
      for (var i = 0; i < 5; i++) {
        touchLatin1('d$i');
      }
      final result = walkAudioFiles(tmp.path);
      expect(result.undecodableNames, 5);
      expect(result.undecodableSampleDirs, hasLength(3));
    });
  });

  group('folders that never hold the library', () {
    test('trash, system and dot folders are skipped at any depth', () {
      touch('keep.mp3');
      touch('.Trash-1000/files/gone.mp3');
      touch('.Trash/gone.mp3');
      touch('lost+found/gone.mp3');
      touch('album/@eaDir/gone.mp3');
      touch(r'$RECYCLE.BIN/gone.mp3');
      touch('.hidden/gone.mp3');
      touch('album/.cache/gone.mp3');
      touch('album/song.mp3');

      final result = walkAudioFiles(tmp.path);

      expect(names(result), {'keep.mp3', 'album/song.mp3'});
      expect(result.skippedFolderNames.toSet(), {
        '.Trash-1000',
        '.Trash',
        'lost+found',
        '@eaDir',
        r'$RECYCLE.BIN',
        '.hidden',
        '.cache',
      });
    });

    test('a dot-file is still a file, and a dot-named root is walked', () {
      touch('.hidden-track.mp3');
      touch('lost+found.mp3');
      expect(names(walkAudioFiles(tmp.path)), {
        '.hidden-track.mp3',
        'lost+found.mp3',
      });

      touch('.music/a.mp3');
      final inner = walkAudioFiles('${tmp.path}/.music');
      expect(inner.files, hasLength(1));
    });
  });
}
