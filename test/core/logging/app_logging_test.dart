import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/app_logging.dart';
import 'package:logging/logging.dart';

class _UnprintableError {
  @override
  String toString() => throw StateError('toString failed');
}

void main() {
  late Directory tmp;
  late LogSession session;
  final log = Logger('test');

  LogSession start({String? level}) => setUpLogging(
    environment: {'XDG_CACHE_HOME': tmp.path, 'KANARU_LOG_LEVEL': ?level},
    console: false,
  );
  List<String> lines() => File(session.filePath!).readAsLinesSync();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kanaru_app_logging_test_');
  });
  tearDown(() async {
    await session.close();
    Logger.root.level = Level.INFO;
    tmp.deleteSync(recursive: true);
  });

  test('writes a header with version, OS, pid and level first', () {
    session = start(level: 'fine');
    expect(session.directory, '${tmp.path}/kanaru/logs');
    expect(session.filePath, '${tmp.path}/kanaru/logs/kanaru.log');
    final header = lines().single;
    expect(header, contains('INFO app: Kanaru $kanaruVersion on linux'));
    expect(header, contains('pid $pid, level FINE'));
    log.fine('kept');
    log.finest('dropped');
    expect(lines().last, endsWith('FINE test: kept'));
    expect(lines(), hasLength(2));
  });

  test('an unknown KANARU_LOG_LEVEL keeps the default and warns', () {
    session = setUpLogging(
      environment: {'XDG_CACHE_HOME': tmp.path, 'KANARU_LOG_LEVEL': 'xyz'},
      console: false,
      defaultLevel: Level.INFO,
    );
    expect(Logger.root.level, Level.INFO);
    expect(lines().first, contains('level INFO'));
    expect(
      lines()[1],
      endsWith('WARNING app: Unknown KANARU_LOG_LEVEL "xyz", using INFO'),
    );
  });

  test('setting up twice leaves a single listener', () {
    start();
    session = start();
    log.info('once');
    // The second setup moves the first file to .1. A first session that was
    // not closed would still write into it, so look at every file.
    final dir = Directory(session.directory!);
    final copies = [
      for (final f in dir.listSync().whereType<File>())
        if (f.path.contains('kanaru.log'))
          ...f.readAsLinesSync().where((l) => l.endsWith('test: once')),
    ];
    expect(copies, hasLength(1));
  });

  test('a record whose error cannot be printed is still logged', () {
    session = start();
    session.installErrorHandlers();
    log.severe('bad', _UnprintableError());
    log.info('after');
    expect(session.filePath, isNotNull);
    final text = lines().join('\n');
    expect(text, contains('SEVERE test: bad'));
    expect(text, contains('  <unprintable _UnprintableError>'));
    expect(text, endsWith('INFO test: after'));
  });

  test('uncaught errors from the platform dispatcher reach the file', () {
    session = start()..installErrorHandlers();
    final handled = PlatformDispatcher.instance.onError!(
      StateError('from a provider'),
      StackTrace.fromString('#0 build (provider.dart:1)'),
    );
    expect(handled, isTrue);
    final text = lines().join('\n');
    expect(text, contains('SHOUT app: Uncaught error'));
    expect(text, contains('  Bad state: from a provider'));
    expect(text, contains('  #0 build (provider.dart:1)'));
  });

  test('framework errors reach the file', () {
    session = start()..installErrorHandlers();
    final presented = <FlutterErrorDetails>[];
    final originalPresent = FlutterError.presentError;
    FlutterError.presentError = presented.add;
    addTearDown(() => FlutterError.presentError = originalPresent);
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError('in build'),
        stack: StackTrace.fromString('#0 Widget.build (w.dart:2)'),
        library: 'widgets library',
      ),
    );
    final text = lines().join('\n');
    expect(text, contains('SEVERE app: Uncaught error in widgets library'));
    expect(text, contains('  #0 Widget.build (w.dart:2)'));
    expect(presented, hasLength(1));
  });

  test('close puts back the previous error handlers', () async {
    final flutterBefore = FlutterError.onError;
    final platformBefore = PlatformDispatcher.instance.onError;
    session = start()..installErrorHandlers();
    expect(FlutterError.onError, isNot(same(flutterBefore)));
    await session.close();
    expect(FlutterError.onError, same(flutterBefore));
    expect(PlatformDispatcher.instance.onError, same(platformBefore));
  });

  test('works without a usable log directory', () {
    session = setUpLogging(environment: {}, console: false);
    expect(session.directory, isNull);
    expect(session.filePath, isNull);
    log.info('console only');
  });
}
