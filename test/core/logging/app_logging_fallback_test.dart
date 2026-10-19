import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/app_logging.dart';
import 'package:logging/logging.dart';

void main() {
  late Directory tmp;
  late LogSession session;
  late List<String> stderrLines;
  final log = Logger('test');

  LogSession start({String? level, bool withDirectory = true}) => setUpLogging(
    environment: {
      if (withDirectory) 'XDG_CACHE_HOME': tmp.path,
      'KANARU_LOG_LEVEL': ?level,
    },
    console: false,
    stderrLine: stderrLines.add,
  );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kanaru_app_fallback_test_');
    stderrLines = [];
  });
  tearDown(() async {
    await session.close();
    Logger.root.level = Level.INFO;
    tmp.deleteSync(recursive: true);
  });

  test('without a log file, warnings and errors go to stderr, redacted', () {
    session = start(withDirectory: false);
    stderrLines.clear(); // The notice that the file is off.
    log.info('quiet');
    log.warning('fetch https://ann:hunter2@dav.example/a?token=t0k failed');
    log.severe('boom', StateError('x'));
    expect(stderrLines, hasLength(2));
    expect(stderrLines[0], contains('WARNING test: fetch'));
    expect(stderrLines[0], isNot(contains('hunter2')));
    expect(stderrLines[0], isNot(contains('t0k')));
    expect(stderrLines[1], contains('SEVERE test: boom'));
  });

  test('a log file that works takes the records, stderr stays quiet', () {
    session = start();
    log.warning('to the file');
    expect(stderrLines, isEmpty);
  });

  test('problems with the file are reported on stderr, redacted', () {
    final blocker = File('${tmp.path}/blocked')..writeAsStringSync('');
    session = setUpLogging(
      environment: {'XDG_CACHE_HOME': blocker.path},
      console: false,
      stderrLine: stderrLines.add,
    );
    expect(stderrLines.single, startsWith('Logging to file is off'));
  });

  test('uncaught errors are written even when the level is OFF', () {
    session = start(level: 'off')..installErrorHandlers();
    log.severe('filtered out');
    PlatformDispatcher.instance.onError!(
      StateError('from a provider'),
      StackTrace.fromString('#0 build (provider.dart:1)'),
    );
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError('in build'),
        stack: StackTrace.fromString('#0 Widget.build (w.dart:2)'),
      ),
    );
    final text = File(session.filePath!).readAsStringSync();
    expect(text, isNot(contains('filtered out')));
    expect(text, contains('SHOUT app: Uncaught error'));
    expect(text, contains('SEVERE app: Uncaught error in Flutter'));
    expect(text, contains('Bad state: from a provider'));
  });

  test('uncaught errors with a failed file still reach stderr', () {
    session = start(withDirectory: false)..installErrorHandlers();
    stderrLines.clear();
    PlatformDispatcher.instance.onError!(StateError('lost?'), StackTrace.empty);
    expect(stderrLines.single, contains('SHOUT app: Uncaught error'));
  });

  test('release builds do not print framework errors to the console', () {
    final originalPresent = FlutterError.presentError;
    final presented = <FlutterErrorDetails>[];
    FlutterError.presentError = presented.add;
    addTearDown(() => FlutterError.presentError = originalPresent);
    session = start()..installErrorHandlers(presentErrors: false);
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: Exception('GET https://bob:pw@dav/a?t=abc'),
      ),
    );
    expect(presented, isEmpty);
    final text = File(session.filePath!).readAsStringSync();
    expect(text, contains('Uncaught error'));
    expect(text, isNot(contains('bob:pw')));
  });
}
