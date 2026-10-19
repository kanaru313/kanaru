import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/rotating_log_file.dart';

/// The `dart` of the Flutter SDK that runs the tests: `flutter test` runs
/// them in `flutter_tester`, which cannot run a script of its own.
String _dartExecutable() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final dart = File('$root/bin/cache/dart-sdk/bin/dart');
    if (dart.existsSync()) return dart.path;
  }
  return 'dart';
}

/// The package root: `flutter test` reports its script as `<root>/main.dart`.
Directory _packageRoot() {
  var dir = File.fromUri(Platform.script).parent;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) return Directory.current;
    dir = parent;
  }
  return dir;
}

void main() {
  late Directory tmp;
  late String dir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kanaru_log_lock_test_');
    dir = '${tmp.path}/logs';
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  String read(String name) => File('$dir/$name').readAsStringSync();
  List<String> names() =>
      [
          for (final e in Directory(dir).listSync())
            e.path.substring(e.path.lastIndexOf('/') + 1),
        ]
        ..remove(RotatingLogFile.lockName)
        ..sort();

  /// Starts `lock_holder_process.dart`, which owns the shared set of [dir].
  /// A lock taken by the test process itself would not block a second open
  /// in the same process.
  Future<Future<String> Function([String? command])> startHolder() async {
    final root = _packageRoot().path;
    final holder = await Process.start(_dartExecutable(), [
      '--packages=$root/.dart_tool/package_config.json',
      '$root/test/core/logging/lock_holder_process.dart',
      dir,
    ], workingDirectory: root);
    addTearDown(holder.kill);
    final replies = StreamIterator(
      holder.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    );
    unawaited(holder.stderr.drain<void>());
    addTearDown(() => holder.stdin.close().catchError((_) {}));
    Future<String> send([String? command]) async {
      if (command != null) {
        holder.stdin.writeln(command);
        await holder.stdin.flush();
      }
      return await replies.moveNext() ? replies.current : '<exited>';
    }

    expect(await send(), 'ready');
    return send;
  }

  test('another process that holds the lock keeps the shared set', () async {
    final holder = await startHolder();

    final second = RotatingLogFile(dir, processId: 4242);
    expect(second.open(), isTrue, reason: '${second.failure}');
    expect(second.ownsSharedSet, isFalse);
    expect(second.path, '$dir/kanaru-4242.log');
    second.write('second');
    second.close();
    expect(read('kanaru-4242.log'), 'second\n');
    // The holder's file was not rotated away.
    expect(names(), ['kanaru-4242.log', 'kanaru.log']);
    expect(read('kanaru.log'), 'holder first\n');

    // The holder rotates mid-session; its lock does not move with the file
    // (it sits on kanaru.lock), so a newcomer is still refused.
    expect(await holder('fill'), 'rotated');
    expect(read('kanaru.log.1'), 'holder first\n');
    expect(read('kanaru.log'), '${'x' * 300}\n');
    final third = RotatingLogFile(dir, processId: 4343);
    expect(third.open(), isTrue);
    expect(third.ownsSharedSet, isFalse);
    third.close();
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'an instance without the lock keeps one backup, with a header',
    () async {
      await startHolder();
      final other = RotatingLogFile(
        dir,
        processId: 4242,
        maxBytes: 50,
        header: 'HEADER',
      );
      expect(other.open(), isTrue, reason: '${other.failure}');
      addTearDown(other.close);
      other.write('a' * 30);
      other.write('b' * 30);
      other.write('c' * 30);
      expect(read('kanaru-4242.log.1'), 'HEADER\n${'b' * 30}\n');
      expect(read('kanaru-4242.log'), 'HEADER\n${'c' * 30}\n');
      expect(read('kanaru.log'), 'holder first\n'); // Shared set untouched.
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
