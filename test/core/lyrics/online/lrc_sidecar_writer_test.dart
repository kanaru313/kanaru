import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';
import 'package:kanaru/core/lyrics/online/lrc_sidecar_writer.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';

const _synced = LyricsBody(syncedLrc: '[00:01.00]one\r\n[00:02.00]two\n\n');

void main() {
  late Directory tmp;
  late String library;
  late String song;
  var excluded = <String>[];
  var roots = <String>[];
  Future<void> Function()? hook;

  FileLrcSidecarWriter writer() => FileLrcSidecarWriter(
    libraryRoots: () async => roots,
    excludedFolders: () async => excluded,
    beforeRecheck: hook == null ? null : () => hook!(),
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

  test('a folder or a dangling link of that name counts', () async {
    Directory('$library/album/a.lrc').createSync();
    expect(await writer().write(song, _synced), LrcWriteResult.exists);
    Directory('$library/album/a.lrc').deleteSync();

    Link('$library/album/a.lrc').createSync('$library/album/missing');
    expect(await writer().write(song, _synced), LrcWriteResult.exists);
    expect(Link('$library/album/a.lrc').existsSync(), isTrue);
    expect(File('$library/album/missing').existsSync(), isFalse);
  });

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
    );

    expect(await failing.write(song, _synced), LrcWriteResult.failed);
    expect(leftovers('$library/album'), isEmpty);
    expect(File('$library/album/a.lrc').existsSync(), isFalse);
  });
}
