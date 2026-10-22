import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/show_in_file_manager.dart';

class _FakeProcess implements Process {
  _FakeProcess(Future<int> exit) : exitCode = exit;

  @override
  final Future<int> exitCode;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const file = '/music/My Album/Café ♪.flac';

  test(
    'a file manager on the bus shows the file and no process starts',
    () async {
      final uris = <String>[];
      final started = <String>[];
      final shown = await showInFileManager(
        file,
        showItems: (uri) async => uris.add(uri),
        start: (executable, arguments) async {
          started.add(executable);
          return _FakeProcess(Future.value(0));
        },
      );

      expect(shown, isTrue);
      expect(started, isEmpty);
      expect(uris, [Uri.file(file).toString()]);
      expect(uris.single, contains('My%20Album'));
      expect(uris.single, startsWith('file:///music/'));
    },
  );

  test('a failing D-Bus call opens the folder with gio', () async {
    final calls = <List<String>>[];
    final shown = await showInFileManager(
      file,
      showItems: (_) async => throw StateError('no service'),
      start: (executable, arguments) async {
        calls.add([executable, ...arguments]);
        return _FakeProcess(Future.value(0));
      },
    );

    expect(shown, isTrue);
    expect(calls, [
      ['gio', 'open', '/music/My Album'],
    ]);
  });

  test('without gio, xdg-open is tried', () async {
    final calls = <String>[];
    final shown = await showInFileManager(
      file,
      showItems: (_) async => throw StateError('no service'),
      start: (executable, arguments) async {
        calls.add(executable);
        if (executable == 'gio') throw const ProcessException('gio', []);
        return _FakeProcess(Future.value(0));
      },
    );

    expect(shown, isTrue);
    expect(calls, ['gio', 'xdg-open']);
  });

  test('false when D-Bus and both openers fail', () async {
    final shown = await showInFileManager(
      file,
      showItems: (_) async => throw StateError('no service'),
      start: (executable, arguments) async =>
          throw ProcessException(executable, []),
    );

    expect(shown, isFalse);
  });

  test('a D-Bus call that hangs counts as shown: no second window', () async {
    final never = Completer<void>();
    final started = <String>[];
    final shown = await showInFileManager(
      file,
      showItems: (_) => never.future,
      dbusTimeout: const Duration(milliseconds: 20),
      start: (executable, arguments) async {
        started.add(executable);
        return _FakeProcess(Future.value(0));
      },
    );

    expect(shown, isTrue);
    expect(started, isEmpty);
  });

  test('gio exiting with an error tries xdg-open', () async {
    final calls = <String>[];
    final shown = await showInFileManager(
      file,
      showItems: (_) async => throw StateError('no service'),
      start: (executable, arguments) async {
        calls.add(executable);
        return _FakeProcess(Future.value(executable == 'gio' ? 1 : 0));
      },
    );

    expect(shown, isTrue);
    expect(calls, ['gio', 'xdg-open']);
  });

  test('an opener that does not return in time counts as opened', () async {
    final calls = <String>[];
    final shown = await showInFileManager(
      file,
      showItems: (_) async => throw StateError('no service'),
      timeout: const Duration(milliseconds: 20),
      start: (executable, arguments) async {
        calls.add(executable);
        return _FakeProcess(Completer<int>().future);
      },
    );

    expect(shown, isTrue);
    expect(calls, ['gio']);
  });

  test('the URI escapes spaces, percent, hash and non-ASCII', () async {
    final uris = <String>[];
    await showInFileManager(
      '/m/A B/100% #1/Café ♪.flac',
      showItems: (uri) async => uris.add(uri),
    );

    expect(
      uris.single,
      'file:///m/A%20B/100%25%20%231/Caf%C3%A9%20%E2%99%AA.flac',
    );
  });
}
