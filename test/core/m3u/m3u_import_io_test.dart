import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/m3u/m3u_import.dart';
import 'package:kanaru/core/m3u/m3u_parse.dart' show m3uMaxPathLines;
import 'package:kanaru/core/m3u/m3u_read.dart';

void main() {
  late Directory tmp;
  late String root;

  String p(String relative) => '$root/$relative';

  Future<void> touch(String relative) async {
    await File(p(relative)).create(recursive: true);
  }

  Future<String> m3u(String body, {String name = 'list/p.m3u8'}) async {
    final file = File(p(name));
    await file.create(recursive: true);
    await file.writeAsString(body);
    return file.path;
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kanaru-m3u-import');
    // Canonical, as the helper returns it (the temp folder may be a link).
    root = await tmp.resolveSymbolicLinks();
    await touch('music/a.flac');
    await touch('music/sub/b.mp3');
    await touch('music/notes.txt');
    await touch('pool/c.flac');
    await Link(p('music/c.flac')).create('../pool/c.flac');
    await Link(p('link')).create(p('music'));
  });
  tearDown(() => tmp.delete(recursive: true));

  test(
    'resolves absolute, relative and file: lines; rejects the rest',
    () async {
      final path = await m3u('''
#EXTM3U
#EXTINF:10,Ann - A
${p('music/a.flac')}
../music/sub/b.mp3
file://${p('music/sub/b.mp3')}
http://example.com/x.mp3
edl://${p('music/a.flac')}
av://lavfi:sine
../music/missing.flac
../link/a.flac
../music/c.flac
file://${p('music/sub/b')}%00.mp3
../music/notes.txt
''');

      final result = await importM3uFile(path);

      expect(result.paths, [
        p('music/a.flac'),
        p('music/sub/b.mp3'),
        // A symlinked file keeps its own name, as the indexer stores it.
        p('music/c.flac'),
      ]);
      // file:// b.mp3 and ../link/a.flac name files already imported.
      expect(result.duplicates, 2);
      expect([for (final u in result.unresolved) u.line], [6, 7, 8, 9, 12, 13]);
      expect(result.total, 11);
      expect(result.truncated, isFalse);
    },
  );

  test('a too long line is unresolved', () async {
    final path = await m3u('${'a' * 5000}.mp3\n');
    final result = await importM3uFile(path);
    expect(result.paths, isEmpty);
    expect(result.unresolved.single.line, 1);
  });

  test('a FIFO named like audio is not imported', () async {
    final fifo = p('music/pipe.mp3');
    final made = await Process.run('mkfifo', [fifo]);
    if (made.exitCode != 0) {
      markTestSkipped('mkfifo is not available');
      return;
    }
    final path = await m3u('../music/pipe.mp3\n');
    final result = await importM3uFile(path);
    expect(result.paths, isEmpty);
    expect(result.unresolved, hasLength(1));
  });

  test('a folder or a FIFO as the M3U file is not a file', () async {
    await expectLater(
      importM3uFile(p('music')),
      throwsA(
        isA<M3uReadException>().having(
          (e) => e.error,
          'error',
          M3uReadError.notAFile,
        ),
      ),
    );
    final fifo = p('list.m3u');
    final made = await Process.run('mkfifo', [fifo]);
    if (made.exitCode != 0) return;
    await expectLater(
      importM3uFile(fifo),
      throwsA(
        isA<M3uReadException>().having(
          (e) => e.error,
          'error',
          M3uReadError.notAFile,
        ),
      ),
    );
  });

  test('a missing M3U file is not a file', () async {
    await expectLater(
      importM3uFile(p('nope.m3u')),
      throwsA(isA<M3uReadException>()),
    );
  });

  test('a file over the size limit is too large', () async {
    final big = File(p('big.m3u'));
    final handle = await big.open(mode: FileMode.write);
    await handle.setPosition(m3uMaxBytes);
    await handle.writeByte(0x0A);
    await handle.close();

    await expectLater(
      importM3uFile(big.path),
      throwsA(
        isA<M3uReadException>().having(
          (e) => e.error,
          'error',
          M3uReadError.tooLarge,
        ),
      ),
    );
  });

  test('reads a file larger than one read, byte for byte', () async {
    // Three reads of 1 MiB plus a tail: the loop must join them all.
    final bytes = List<int>.generate(3 * 1024 * 1024 + 7, (i) => i % 251);
    final file = File(p('large.m3u'));
    await file.writeAsBytes(bytes);

    expect(await readM3uBytes(file.path), bytes);
  });

  test('a file of exactly the cap is read, one byte more is not', () async {
    final file = File(p('cap.m3u'));
    await file.writeAsBytes(List.filled(10, 0x41));
    expect(await readM3uBytes(file.path, maxBytes: 10), hasLength(10));

    await file.writeAsBytes(List.filled(11, 0x41));
    await expectLater(
      readM3uBytes(file.path, maxBytes: 10),
      throwsA(
        isA<M3uReadException>().having(
          (e) => e.error,
          'error',
          M3uReadError.tooLarge,
        ),
      ),
    );
  });

  test('a file that reports size 0 is still read to the end', () async {
    // procfs reports 0 for its files, as some network mounts do.
    // smaps runs to tens of KiB, far past what one read returns there.
    final bytes = await readM3uBytes('/proc/self/smaps');
    expect(bytes.length, greaterThan(16 * 1024));
  }, skip: Platform.isLinux ? false : 'procfs is Linux only');

  test('cancelling stops the import', () async {
    final path = await m3u('../music/a.flac\n../music/sub/b.mp3\n');
    var calls = 0;
    await expectLater(
      importM3uFile(path, cancelled: () => ++calls > 1),
      throwsA(isA<M3uImportCancelled>()),
    );
  });

  // KANARU_BENCH=1 flutter test test/core/m3u/m3u_import_io_test.dart
  test(
    'bench: 50 000 lines import in reasonable time',
    () async {
      for (var i = 0; i < 500; i++) {
        await touch('bench/$i.flac');
      }
      final lines = [
        for (var i = 0; i < m3uMaxPathLines; i++) '../bench/${i % 500}.flac',
      ];
      final path = await m3u(lines.join('\n'));
      final watch = Stopwatch()..start();

      final result = await importM3uFile(path);

      // ignore: avoid_print
      print(
        'Imported ${result.total} lines in ${watch.elapsedMilliseconds} ms',
      );
      expect(result.paths, hasLength(500));
      expect(watch.elapsed, lessThan(const Duration(seconds: 15)));
    },
    skip: Platform.environment['KANARU_BENCH'] == '1'
        ? false
        : 'set KANARU_BENCH=1',
  );
}
