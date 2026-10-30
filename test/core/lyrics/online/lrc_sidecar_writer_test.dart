import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';
import 'package:kanaru/core/lyrics/online/lrc_sidecar_writer.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/native/file_trash.dart';

import 'fake_file_trash.dart';

const _synced = LyricsBody(syncedLrc: '[00:01.00]one\r\n[00:02.00]two\n\n');

void main() {
  late Directory tmp;
  late String library;
  late String song;
  var excluded = <String>[];
  var roots = <String>[];
  Future<void> Function()? hook;
  late FakeFileTrash trash;
  DateTime Function()? clock;

  FileLrcSidecarWriter writer() => FileLrcSidecarWriter(
    libraryRoots: () async => roots,
    excludedFolders: () async => excluded,
    trash: trash,
    beforeRecheck: hook == null ? null : () => hook!(),
    now: clock,
  );

  String newSong(String dir, [String name = 'a.mp3']) {
    Directory(dir).createSync(recursive: true);
    final path = '$dir/$name';
    File(path).writeAsBytesSync([1, 2, 3]);
    return path;
  }

  List<String> leftovers(String dir) => [
    for (final e in Directory(dir).listSync())
      if (e.path.split('/').last.startsWith('.kanaru-lrc-')) e.path,
  ];

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kanaru_lrc_');
    // Roots are canonical in the database.
    library = '${tmp.resolveSymbolicLinksSync()}/library';
    song = newSong('$library/album');
    roots = [library];
    excluded = [];
    hook = null;
    clock = null;
    trash = FakeFileTrash('${tmp.path}/trash');
  });

  tearDown(() {
    // A test may leave a read-only folder behind.
    Process.runSync('chmod', ['-R', 'u+rwx', tmp.path]);
    tmp.deleteSync(recursive: true);
  });

  test('writes the synced lyrics: LF, one final newline, no BOM', () async {
    expect(await writer().write(song, _synced), LrcWriteResult.written);

    final bytes = File('$library/album/a.lrc').readAsBytesSync();
    expect(utf8.decode(bytes), '[00:01.00]one\n[00:02.00]two\n');
    expect(bytes.take(3), isNot([0xEF, 0xBB, 0xBF]));
    expect(leftovers('$library/album'), isEmpty);
  });

  test('falls back on the plain text and keeps non-ASCII', () async {
    const body = LyricsBody(plain: 'Xin chào\nthế giới');

    expect(await writer().write(song, body), LrcWriteResult.written);
    expect(
      File('$library/album/a.lrc').readAsStringSync(),
      'Xin chào\nthế giới\n',
    );
  });

  test('nothing to write: instrumental, no text, too large', () async {
    final tooLarge = LyricsBody(plain: 'x' * (lrcMaxBytes + 1));
    for (final body in [
      const LyricsBody(instrumental: true, plain: 'ignored'),
      const LyricsBody(),
      tooLarge,
    ]) {
      expect(await writer().write(song, body), LrcWriteResult.nothingToWrite);
    }
    expect(File('$library/album/a.lrc').existsSync(), isFalse);
    expect(leftovers('$library/album'), isEmpty);
  });

  test('exactly the size limit is written', () async {
    final body = LyricsBody(plain: 'x' * (lrcMaxBytes - 1));

    expect(await writer().write(song, body), LrcWriteResult.written);
  });

  test('an existing .lrc is never overwritten', () async {
    File('$library/album/a.lrc').writeAsStringSync('mine');

    expect(await writer().write(song, _synced), LrcWriteResult.exists);
    expect(File('$library/album/a.lrc').readAsStringSync(), 'mine');
    expect(leftovers('$library/album'), isEmpty);
  });

  test('an existing .LRC alone also counts', () async {
    File('$library/album/a.LRC').writeAsStringSync('mine');

    expect(await writer().write(song, _synced), LrcWriteResult.exists);
    expect(File('$library/album/a.LRC').readAsStringSync(), 'mine');
    expect(File('$library/album/a.lrc').existsSync(), isFalse);
  });

  test(
    'a folder of that name cannot be replaced, a dangling link counts',
    () async {
      Directory('$library/album/a.lrc').createSync();
      expect(await writer().write(song, _synced), LrcWriteResult.trashFailed);
      Directory('$library/album/a.lrc').deleteSync();

      Link('$library/album/a.lrc').createSync('$library/album/missing');
      expect(await writer().write(song, _synced), LrcWriteResult.exists);
      expect(Link('$library/album/a.lrc').existsSync(), isTrue);
      expect(File('$library/album/missing').existsSync(), isFalse);
    },
  );

  test('a candidate that appears before the rename is not replaced', () async {
    hook = () async {
      // The temp file is already there when the other program writes.
      expect(leftovers('$library/album'), hasLength(1));
      File('$library/album/a.lrc').writeAsStringSync('late');
    };

    expect(await writer().write(song, _synced), LrcWriteResult.exists);
    expect(File('$library/album/a.lrc').readAsStringSync(), 'late');
    expect(leftovers('$library/album'), isEmpty);
  });

  test('a link planted at a temp-like name is left alone', () async {
    final victim = File('$library/album/victim')..writeAsStringSync('keep');
    Link('$library/album/.kanaru-lrc-guess').createSync(victim.path);

    expect(await writer().write(song, _synced), LrcWriteResult.written);
    expect(victim.readAsStringSync(), 'keep');
    expect(Link('$library/album/.kanaru-lrc-guess').targetSync(), victim.path);
  });

  test(
    'a read-only folder gives failed, leaves nothing, never throws',
    () async {
      if (Process.runSync('id', ['-u']).stdout.toString().trim() == '0') {
        markTestSkipped('root ignores folder permissions');
        return;
      }
      Process.runSync('chmod', ['555', '$library/album']);

      expect(await writer().write(song, _synced), LrcWriteResult.failed);
      expect(leftovers('$library/album'), isEmpty);
      expect(File('$library/album/a.lrc').existsSync(), isFalse);
    },
  );

  test('a song outside the library roots is outsideLibrary', () async {
    final other = newSong('${tmp.path}/elsewhere');

    expect(await writer().write(other, _synced), LrcWriteResult.outsideLibrary);
    expect(Directory('${tmp.path}/elsewhere').listSync(), hasLength(1));
  });

  test('a song in an excluded folder is outsideLibrary', () async {
    excluded = ['$library/album'];

    expect(await writer().write(song, _synced), LrcWriteResult.outsideLibrary);
    expect(Directory('$library/album').listSync(), hasLength(1));
  });

  test('no roots means outsideLibrary', () async {
    roots = [];

    expect(await writer().write(song, _synced), LrcWriteResult.outsideLibrary);
  });

  test('a missing song or a folder is outsideLibrary', () async {
    expect(
      await writer().write('$library/album/gone.mp3', _synced),
      LrcWriteResult.outsideLibrary,
    );
    expect(
      await writer().write('$library/album', _synced),
      LrcWriteResult.outsideLibrary,
    );
  });

  test(
    'a link in the library to a file outside it is outsideLibrary',
    () async {
      final outside = newSong('${tmp.path}/outside', 'real.mp3');
      Link('$library/album/linked.mp3').createSync(outside);

      expect(
        await writer().write('$library/album/linked.mp3', _synced),
        LrcWriteResult.outsideLibrary,
      );
      expect(File('$library/album/linked.lrc').existsSync(), isFalse);
    },
  );

  test(
    'a song reached through a linked folder outside is outsideLibrary',
    () async {
      final outside = newSong('${tmp.path}/outside', 'real.mp3');
      Link('$library/via').createSync(File(outside).parent.path);

      expect(
        await writer().write('$library/via/real.mp3', _synced),
        LrcWriteResult.outsideLibrary,
      );
      expect(File('${tmp.path}/outside/real.lrc').existsSync(), isFalse);
    },
  );

  test(
    'a link from outside to a song inside the library is outsideLibrary',
    () async {
      Directory('${tmp.path}/out').createSync();
      Link('${tmp.path}/out/pointer.mp3').createSync(song);

      expect(
        await writer().write('${tmp.path}/out/pointer.mp3', _synced),
        LrcWriteResult.outsideLibrary,
      );
      expect(Directory('${tmp.path}/out').listSync(), hasLength(1));
    },
  );

  test('a library folder reached through a link is allowed', () async {
    Link('${tmp.path}/shortcut').createSync(library);

    expect(
      await writer().write('${tmp.path}/shortcut/album/a.mp3', _synced),
      LrcWriteResult.written,
    );
    expect(File('$library/album/a.lrc').existsSync(), isTrue);
  });

  test('a relative path is outsideLibrary', () async {
    expect(
      await writer().write('a.mp3', _synced),
      LrcWriteResult.outsideLibrary,
    );
  });

  test(
    'no placeholder is visible under the final name while writing',
    () async {
      final seen = <bool>[];
      hook = () async => seen.add(File('$library/album/a.lrc').existsSync());

      await writer().write(song, _synced);

      expect(seen, [false]);
    },
  );

  test('blank synced lyrics fall back on real plain ones', () async {
    const body = LyricsBody(syncedLrc: ' \n ', plain: 'words');

    expect(await writer().write(song, body), LrcWriteResult.written);
    expect(File('$library/album/a.lrc').readAsStringSync(), 'words\n');
  });

  test('only blank text is nothing to write', () async {
    const body = LyricsBody(syncedLrc: '  ', plain: '\n');

    expect(await writer().write(song, body), LrcWriteResult.nothingToWrite);
  });

  test('an error that is not a file error still gives failed', () async {
    final failing = FileLrcSidecarWriter(
      libraryRoots: () async => throw StateError('closed'),
      excludedFolders: () async => excluded,
      trash: trash,
    );

    expect(await failing.write(song, _synced), LrcWriteResult.failed);
    expect(leftovers('$library/album'), isEmpty);
    expect(File('$library/album/a.lrc').existsSync(), isFalse);
  });

  group('same text', () {
    test('an identical file is reported and left alone', () async {
      File('$library/album/a.lrc')
          .writeAsStringSync('[00:01.00]one\n[00:02.00]two\n');

      expect(await writer().write(song, _synced), LrcWriteResult.identical);
      expect(trash.calls, isEmpty);
      expect(leftovers('$library/album'), isEmpty);
    });

    test('identical is read from the first spelling that exists', () async {
      File('$library/album/a.LRC')
          .writeAsStringSync('[00:01.00]one\n[00:02.00]two\n');

      expect(await writer().write(song, _synced), LrcWriteResult.identical);
    });

    test('a FIFO named .lrc is not identical and does not hang', () async {
      Process.runSync('mkfifo', ['$library/album/a.lrc']);

      // It can never be replaced, so the user is not asked to confirm.
      expect(await writer().write(song, _synced), LrcWriteResult.trashFailed);
      expect(trash.calls, isEmpty);
    });

    test('an oversized file is not identical', () async {
      File('$library/album/a.lrc').writeAsStringSync('x' * (lrcMaxBytes + 1));

      expect(await writer().write(song, _synced), LrcWriteResult.exists);
    });

    test('synced text that does not parse writes the plain text', () async {
      const body = LyricsBody(syncedLrc: '[00:01.00]   ', plain: 'real words');

      expect(await writer().write(song, body), LrcWriteResult.written);
      expect(File('$library/album/a.lrc').readAsStringSync(), 'real words\n');
    });
  });

  group('replace', () {
    String lrc() => '$library/album/a.lrc';
    String upper() => '$library/album/a.LRC';

    test(
      'the old file goes to the trash, then the new one is written',
      () async {
        File(lrc()).writeAsStringSync('mine');

        expect(
          await writer().write(song, _synced, replace: true),
          LrcWriteResult.written,
        );
        expect(trash.calls, [lrc()]);
        expect(File('${trash.folder}/1').readAsStringSync(), 'mine');
        expect(
          File(lrc()).readAsStringSync(),
          '[00:01.00]one\n[00:02.00]two\n',
        );
        expect(leftovers('$library/album'), isEmpty);
      },
    );

    test('replace without an existing file just writes', () async {
      expect(
        await writer().write(song, _synced, replace: true),
        LrcWriteResult.written,
      );
      expect(trash.calls, isEmpty);
    });

    test('both spellings are trashed in order', () async {
      // A case-sensitive folder can hold both.
      File(lrc()).writeAsStringSync('lower');
      File(upper()).writeAsStringSync('upper');

      expect(
        await writer().write(song, _synced, replace: true),
        LrcWriteResult.written,
      );
      expect(trash.calls, [lrc(), upper()]);
      expect(File(upper()).existsSync(), isFalse);
    });

    for (final refusal in [TrashResult.unsupported, TrashResult.failed]) {
      test('trash $refusal gives trashFailed and changes nothing', () async {
        File(lrc()).writeAsStringSync('mine');
        trash.results.add(refusal);

        expect(
          await writer().write(song, _synced, replace: true),
          LrcWriteResult.trashFailed,
        );
        expect(File(lrc()).readAsStringSync(), 'mine');
        expect(leftovers('$library/album'), isEmpty);
      });
    }

    test('a trash timeout on the first file is trashTimedOut', () async {
      File(lrc()).writeAsStringSync('mine');
      trash.results.add(TrashResult.timedOut);

      expect(
        await writer().write(song, _synced, replace: true),
        LrcWriteResult.trashTimedOut,
      );
      expect(File(lrc()).readAsStringSync(), 'mine');
      expect(leftovers('$library/album'), isEmpty);
    });

    test('a timeout after an earlier trash is trashedNotWritten', () async {
      File(lrc()).writeAsStringSync('lower');
      File(upper()).writeAsStringSync('upper');
      trash.results.addAll([TrashResult.trashed, TrashResult.timedOut]);

      expect(
        await writer().write(song, _synced, replace: true),
        LrcWriteResult.trashedNotWritten,
      );
    });

    test('a failing second trash is trashedNotWritten', () async {
      File(lrc()).writeAsStringSync('lower');
      File(upper()).writeAsStringSync('upper');
      trash.results.addAll([TrashResult.trashed, TrashResult.failed]);

      expect(
        await writer().write(song, _synced, replace: true),
        LrcWriteResult.trashedNotWritten,
      );
      expect(File(lrc()).existsSync(), isFalse);
      expect(File(upper()).readAsStringSync(), 'upper');
      expect(leftovers('$library/album'), isEmpty);
    });

    test(
      'a file that reappears after the trash is trashedNotWritten',
      () async {
        File(lrc()).writeAsStringSync('mine');
        trash.afterTrashed = (_) => File(lrc()).writeAsStringSync('again');

        expect(
          await writer().write(song, _synced, replace: true),
          LrcWriteResult.trashedNotWritten,
        );
        expect(File(lrc()).readAsStringSync(), 'again');
        expect(leftovers('$library/album'), isEmpty);
      },
    );

    test('a folder named .LRC stops the replace before any trash', () async {
      File(lrc()).writeAsStringSync('mine');
      Directory(upper()).createSync();

      expect(
        await writer().write(song, _synced, replace: true),
        LrcWriteResult.trashFailed,
      );
      expect(trash.calls, isEmpty);
      expect(File(lrc()).readAsStringSync(), 'mine');
      expect(leftovers('$library/album'), isEmpty);
    });

    test('a dangling link is trashed as a link', () async {
      Link(lrc()).createSync('$library/album/missing');

      expect(
        await writer().write(song, _synced, replace: true),
        LrcWriteResult.written,
      );
      expect(trash.calls, [lrc()]);
      expect(Link('${trash.folder}/1').existsSync(), isTrue);
    });

    test('a read-only folder gives failed with nothing trashed', () async {
      if (Process.runSync('id', ['-u']).stdout.toString().trim() == '0') {
        markTestSkipped('root ignores folder permissions');
        return;
      }
      File(lrc()).writeAsStringSync('mine');
      Process.runSync('chmod', ['555', '$library/album']);

      expect(
        await writer().write(song, _synced, replace: true),
        LrcWriteResult.failed,
      );
      expect(trash.calls, isEmpty);
      expect(File(lrc()).readAsStringSync(), 'mine');
    });

    test('a failed rename after the trash is trashedNotWritten', () async {
      File(lrc()).writeAsStringSync('mine');
      // The destination is a folder by the time of the rename.
      trash.afterTrashed = (_) => Directory(lrc()).createSync();

      expect(
        await writer().write(song, _synced, replace: true),
        LrcWriteResult.trashedNotWritten,
      );
    });
  });

  group('stale temp folders', () {
    test('an old one is removed and a fresh one is kept', () async {
      Directory('$library/album/.kanaru-lrc-old').createSync();
      Directory('$library/album/.kanaru-lrc-fresh').createSync();
      Directory('$library/album/other').createSync();

      // Both are "now"; a clock 11 minutes ahead makes them old.
      clock = () => DateTime.now().add(const Duration(minutes: 11));
      await writer().write(song, _synced);
      expect(leftovers('$library/album'), isEmpty);
      expect(Directory('$library/album/other').existsSync(), isTrue);

      Directory('$library/album/.kanaru-lrc-fresh').createSync();
      clock = null;
      File('$library/album/a.lrc').deleteSync();
      await writer().write(song, _synced);
      expect(leftovers('$library/album'), ['$library/album/.kanaru-lrc-fresh']);
    });

    test('a link with the temp name is not followed', () async {
      final outside = Directory('${tmp.path}/outside')..createSync();
      File('${outside.path}/keep').writeAsStringSync('x');
      Link('$library/album/.kanaru-lrc-link').createSync(outside.path);

      clock = () => DateTime.now().add(const Duration(minutes: 11));
      await writer().write(song, _synced);

      expect(File('${outside.path}/keep').existsSync(), isTrue);
    });
  });
}
