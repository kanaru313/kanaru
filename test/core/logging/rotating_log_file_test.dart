import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/rotating_log_file.dart';

void main() {
  late Directory tmp;
  late String dir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kanaru_log_test_');
    dir = '${tmp.path}/logs';
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  List<String> names() =>
      [
          for (final e in Directory(dir).listSync())
            e.path.substring(e.path.lastIndexOf('/') + 1),
        ]
        ..remove(RotatingLogFile.lockName)
        ..sort();
  String read(String name) => File('$dir/$name').readAsStringSync();

  void session(String line, {int maxFiles = 5}) {
    final file = RotatingLogFile(dir, maxFiles: maxFiles);
    expect(file.open(), isTrue, reason: '${file.failure}');
    file.write(line);
    file.close();
  }

  test('the first session does not rotate', () {
    session('one');
    expect(names(), ['kanaru.log']);
    expect(read('kanaru.log'), 'one\n');
    expect(File('$dir/kanaru.lock').existsSync(), isTrue);
  });

  test('a new session moves the previous one to .1', () {
    session('one');
    session('two');
    expect(names(), ['kanaru.log', 'kanaru.log.1']);
    expect(read('kanaru.log'), 'two\n');
    expect(read('kanaru.log.1'), 'one\n');
  });

  test('six sessions keep the current file and four old ones', () {
    for (var i = 1; i <= 6; i++) {
      session('s$i');
    }
    expect(names(), [
      'kanaru.log',
      'kanaru.log.1',
      'kanaru.log.2',
      'kanaru.log.3',
      'kanaru.log.4',
    ]);
    expect(read('kanaru.log'), 's6\n');
    expect(read('kanaru.log.4'), 's2\n');
  });

  test('rotation skips gaps and deletes stray high numbers', () {
    Directory(dir).createSync(recursive: true);
    File('$dir/kanaru.log').writeAsStringSync('current\n');
    File('$dir/kanaru.log.1').writeAsStringSync('one\n');
    File('$dir/kanaru.log.3').writeAsStringSync('three\n');
    File('$dir/kanaru.log.7').writeAsStringSync('seven\n');
    session('new');
    expect(names(), [
      'kanaru.log',
      'kanaru.log.1',
      'kanaru.log.2',
      'kanaru.log.4',
    ]);
    expect(read('kanaru.log.1'), 'current\n');
    expect(read('kanaru.log.2'), 'one\n');
    expect(read('kanaru.log.4'), 'three\n');
  });

  test('odd numbered names do not stop rotation', () {
    Directory(dir).createSync(recursive: true);
    File('$dir/kanaru.log').writeAsStringSync('current\n');
    File('$dir/kanaru.log.01').writeAsStringSync('zero one\n');
    File('$dir/kanaru.log.99999999999999999999').writeAsStringSync('big\n');
    final file = RotatingLogFile(dir);
    expect(file.open(), isTrue, reason: '${file.failure}');
    file.close();
    expect(read('kanaru.log.1'), 'current\n');
    expect(read('kanaru.log.01'), 'zero one\n');
  });

  test('a write that fails turns the sink off and says so', () {
    final file = RotatingLogFile(dir, maxBytes: 10)..open();
    expect(file.write('first line'), isTrue);
    // The next write must start a new file, which cannot be opened when a
    // directory has taken the name. Does not depend on permissions, so it
    // also fails as root.
    File('$dir/kanaru.log').deleteSync();
    Directory('$dir/kanaru.log/inside').createSync(recursive: true);
    expect(file.write('second line'), isFalse);
    expect(file.isOpen, isFalse);
    expect(file.failure, isA<FileSystemException>());
    expect(file.write('third'), isFalse);
  });

  test('a file past maxBytes rotates mid-session', () {
    final file = RotatingLogFile(dir, maxBytes: 50)..open();
    file.write('a' * 30);
    file.write('b' * 30);
    file.close();
    expect(read('kanaru.log.1'), '${'a' * 30}\n');
    expect(read('kanaru.log'), '${'b' * 30}\n');
  });

  test('the owner keeps only the four newest kanaru-<pid>.log files', () {
    Directory(dir).createSync(recursive: true);
    final now = DateTime.now();
    for (var i = 1; i <= 6; i++) {
      File('$dir/kanaru-$i.log')
        ..writeAsStringSync('pid $i\n')
        ..setLastModifiedSync(now.subtract(Duration(minutes: 10 - i)));
    }
    session('owner');
    expect(names(), [
      'kanaru-3.log',
      'kanaru-4.log',
      'kanaru-5.log',
      'kanaru-6.log',
      'kanaru.log',
    ]);
  });

  test('an unusable directory turns the sink off without throwing', () {
    final blocker = File('${tmp.path}/not_a_dir')..writeAsStringSync('');
    final file = RotatingLogFile('${blocker.path}/logs');
    expect(file.open(), isFalse);
    expect(file.isOpen, isFalse);
    expect(file.path, isNull);
    expect(file.failure, isA<FileSystemException>());
    file.write('dropped');
    file.close();
  });
}
