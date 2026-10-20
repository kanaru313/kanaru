import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/app_logging.dart';
import 'package:logging/logging.dart';

void main() {
  late Directory tmp;
  late LogSession session;
  late String path;

  void raise(Object error, String stack) {
    PlatformDispatcher.instance.onError!(error, StackTrace.fromString(stack));
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kanaru_repeat_test_');
    session = setUpLogging(
      environment: {'XDG_CACHE_HOME': tmp.path},
      console: false,
    )..installErrorHandlers(presentErrors: false);
    path = session.filePath!;
  });
  tearDown(() async {
    await session.close();
    Logger.root.level = Level.INFO;
    tmp.deleteSync(recursive: true);
  });

  test('a burst of one error is written once, the count on close', () async {
    for (var i = 0; i < 100; i++) {
      raise(StateError('boom'), '#0 build (w.dart:1)');
    }
    expect(
      File(path).readAsLinesSync().where((l) => l.contains('Uncaught error')),
      hasLength(1),
    );
    await session.close();
    final lines = File(path).readAsLinesSync();
    expect(lines.where((l) => l == '  Bad state: boom'), hasLength(1));
    expect(
      lines.last,
      endsWith(
        'SEVERE app: Uncaught error repeated ×99: '
        'StateError #0 build (w.dart:1) | Bad state: boom',
      ),
    );
  });

  test('another error is written in full; the count comes on close', () async {
    raise(StateError('a'), '#0 one (a.dart:1)');
    raise(StateError('a'), '#0 one (a.dart:1)');
    raise(ArgumentError('b'), '#0 two (b.dart:1)');
    final text = File(path).readAsStringSync();
    expect(text, contains('Invalid argument(s): b'));
    expect(text, isNot(contains('repeated')));
    await session.close();
    expect(
      File(path).readAsStringSync(),
      contains('Uncaught error repeated ×1: StateError #0 one'),
    );
  });

  test('the summary is redacted and escaped like any record', () async {
    const stack = '#0 get\r\u2028(https://u:pw@h/x?token=sek)';
    raise(StateError('a'), stack);
    raise(StateError('a'), stack);
    await session.close();
    final text = File(path).readAsStringSync();
    final summary = text
        .split('\n')
        .lastWhere((l) => l.contains('repeated ×1'));
    expect(summary, isNot(contains('sek')));
    expect(summary, isNot(contains('pw@')));
    expect(summary, contains(r'\r'));
    expect(summary, contains(r'\u2028'));
    expect(summary, isNot(contains('\r')));
  });

  test('errors that alternate are folded, not written every time', () async {
    for (var i = 0; i < 20; i++) {
      raise(StateError('a'), '#0 one (a.dart:1)');
      raise(StateError('b'), '#0 two (b.dart:1)');
    }
    await session.close();
    final lines = File(path).readAsLinesSync();
    expect(lines.where((l) => l == '  Bad state: a'), hasLength(1));
    expect(lines.where((l) => l == '  Bad state: b'), hasLength(1));
    expect(lines.where((l) => l.contains('repeated ×19')), hasLength(2));
  });
}
