import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/settings/open_external.dart';

class _FakeProcess implements Process {
  _FakeProcess(Future<int> exit) : exitCode = exit;

  @override
  final Future<int> exitCode;

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('opens with gio when it succeeds', () async {
    final calls = <List<String>>[];
    final opened = await openExternal(
      '/tmp/x',
      start: (executable, arguments) async {
        calls.add([executable, ...arguments]);
        return _FakeProcess(Future.value(0));
      },
    );

    expect(opened, isTrue);
    expect(calls, [
      ['gio', 'open', '/tmp/x'],
    ]);
  });

  test('falls back to xdg-open when gio is missing', () async {
    final calls = <String>[];
    final opened = await openExternal(
      'https://example.com',
      start: (executable, arguments) async {
        calls.add(executable);
        if (executable == 'gio') throw const ProcessException('gio', []);
        return _FakeProcess(Future.value(0));
      },
    );

    expect(opened, isTrue);
    expect(calls, ['gio', 'xdg-open']);
  });

  test('falls back when gio exits non-zero', () async {
    final calls = <String>[];
    final opened = await openExternal(
      '/tmp/x',
      start: (executable, arguments) async {
        calls.add(executable);
        return _FakeProcess(Future.value(executable == 'gio' ? 2 : 0));
      },
    );

    expect(opened, isTrue);
    expect(calls, ['gio', 'xdg-open']);
  });

  test('returns false when every opener fails', () async {
    final opened = await openExternal(
      '/tmp/x',
      start: (executable, arguments) async {
        if (executable == 'gio') throw const ProcessException('gio', []);
        return _FakeProcess(Future.value(1));
      },
    );

    expect(opened, isFalse);
  });

  test('treats an opener that keeps running as success', () async {
    final never = Completer<int>();
    final opened = await openExternal(
      '/tmp/x',
      timeout: const Duration(milliseconds: 10),
      start: (executable, arguments) async => _FakeProcess(never.future),
    );

    expect(opened, isTrue);
  });

  test('creates the directory before opening it', () async {
    final root = Directory.systemTemp.createTempSync('kanaru_open_');
    addTearDown(() => root.deleteSync(recursive: true));
    final target = '${root.path}/a/b';
    String? opened;

    final ok = await openDirectory(
      target,
      open: (path) async {
        opened = path;
        return true;
      },
    );

    expect(ok, isTrue);
    expect(opened, target);
    expect(Directory(target).existsSync(), isTrue);
  });

  test('returns false when the directory cannot be created', () async {
    final root = Directory.systemTemp.createTempSync('kanaru_open_');
    addTearDown(() => root.deleteSync(recursive: true));
    final blocker = File('${root.path}/file')..writeAsStringSync('x');

    final ok = await openDirectory(
      '${blocker.path}/sub',
      open: (path) async => fail('must not open'),
    );

    expect(ok, isFalse);
  });
}
