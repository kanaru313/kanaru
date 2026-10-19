import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/rotating_log_file.dart';

void main() {
  late Directory tmp;
  late String dir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kanaru_log_recovery_test_');
    dir = '${tmp.path}/logs';
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  String read(String name) => File('$dir/$name').readAsStringSync();

  RotatingLogFile open({int maxBytes = 40, String? header}) {
    final file = RotatingLogFile(dir, maxBytes: maxBytes, header: header);
    expect(file.open(), isTrue, reason: '${file.failure}');
    addTearDown(file.close);
    return file;
  }

  test('a file started by a rotation begins with the header', () {
    final file = open(header: 'HEADER');
    file.write('a' * 30);
    file.write('b' * 30);
    expect(read('kanaru.log.1'), '${'a' * 30}\n');
    expect(read('kanaru.log'), 'HEADER\n${'b' * 30}\n');
  });

  test('a rotation that cannot move a file stops the chain, loses nothing', () {
    Directory(dir).createSync(recursive: true);
    File('$dir/kanaru.log').writeAsStringSync('current\n');
    File('$dir/kanaru.log.1').writeAsStringSync('one\n');
    File('$dir/kanaru.log.2').writeAsStringSync('two\n');
    // .2 cannot move onto a directory with content. Moving .1 to .2
    // anyway would overwrite the file that is still there.
    Directory('$dir/kanaru.log.3/inside').createSync(recursive: true);
    open().close();
    expect(read('kanaru.log'), 'current\n');
    expect(read('kanaru.log.1'), 'one\n');
    expect(read('kanaru.log.2'), 'two\n');
  });

  test('a current file that cannot be moved keeps being written', () {
    Directory('$dir/kanaru.log.1/inside').createSync(recursive: true);
    final file = open(maxBytes: 20);
    for (final line in ['a' * 15, 'b' * 15, 'c' * 15, 'd' * 15]) {
      expect(file.write(line), isTrue, reason: '${file.failure}');
    }
    expect(file.isOpen, isTrue);
    expect(
      read('kanaru.log'),
      ['a', 'b', 'c', 'd'].map((c) => '${c * 15}\n').join(),
    );
  });

  test('a lock file that cannot be opened gives a pid file, not silence', () {
    Directory('$dir/kanaru.lock').createSync(recursive: true);
    final file = RotatingLogFile(dir, processId: 77);
    addTearDown(file.close);
    expect(file.open(), isTrue, reason: '${file.failure}');
    expect(file.ownsSharedSet, isFalse);
    expect(file.path, '$dir/kanaru-77.log');
  });

  test('pruning removes the .1 backup together with its pid file', () {
    Directory(dir).createSync(recursive: true);
    final now = DateTime.now();
    for (var i = 1; i <= 6; i++) {
      for (final name in ['kanaru-$i.log', 'kanaru-$i.log.1']) {
        File('$dir/$name')
          ..writeAsStringSync('$name\n')
          ..setLastModifiedSync(now.subtract(Duration(minutes: 10 - i)));
      }
    }
    open().close();
    final left = Directory(dir)
        .listSync()
        .map((e) => e.path.substring(dir.length + 1))
        .where((n) => n.startsWith('kanaru-'));
    expect(left.toSet(), {
      for (var i = 3; i <= 6; i++) ...['kanaru-$i.log', 'kanaru-$i.log.1'],
    });
  });

  group('files deleted while the app runs', () {
    final skip = Platform.isLinux ? null : 'needs /proc';

    test('the next rotation makes the directory and the lock again', () {
      final file = open(header: 'HEADER');
      file.write('a' * 30);
      Directory(dir).deleteSync(recursive: true);
      file.write('b' * 30);
      expect(file.isOpen, isTrue, reason: '${file.failure}');
      expect(file.ownsSharedSet, isTrue);
      expect(read('kanaru.log'), 'HEADER\n${'b' * 30}\n');
      expect(File('$dir/kanaru.lock').existsSync(), isTrue);
    }, skip: skip);

    test('a deleted lock file is made again, the log set is rotated', () {
      final file = open(header: 'HEADER');
      file.write('a' * 30);
      File('$dir/kanaru.lock').deleteSync();
      file.write('b' * 30);
      expect(file.ownsSharedSet, isTrue);
      expect(File('$dir/kanaru.lock').existsSync(), isTrue);
      expect(read('kanaru.log.1'), '${'a' * 30}\n');
      expect(read('kanaru.log'), 'HEADER\n${'b' * 30}\n');
    }, skip: skip);
  });
}
