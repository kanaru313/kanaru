import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/app_logging.dart';
import 'package:logging/logging.dart';

void main() {
  late Directory tmp;
  late LogSession session;
  late FlutterExceptionHandler? previousOnError;
  late void Function(FlutterErrorDetails) previousPresent;
  late List<FlutterErrorDetails> presented;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kanaru_present_test_');
    previousOnError = FlutterError.onError;
    previousPresent = FlutterError.presentError;
    presented = [];
    FlutterError.presentError = presented.add;
    session = setUpLogging(
      environment: {'XDG_CACHE_HOME': tmp.path},
      console: false,
    )..installErrorHandlers(presentErrors: true);
  });
  tearDown(() async {
    final path = session.filePath;
    await session.close();
    expect(path, isNotNull);
    FlutterError.onError = previousOnError;
    FlutterError.presentError = previousPresent;
    Logger.root.level = Level.INFO;
    tmp.deleteSync(recursive: true);
  });

  test('every repeat reaches the console, only the first the file', () {
    for (var i = 0; i < 5; i++) {
      FlutterError.onError!(
        FlutterErrorDetails(
          exception: StateError('in build'),
          stack: StackTrace.fromString('#0 Widget.build (w.dart:2)'),
        ),
      );
    }
    expect(presented, hasLength(5));
    final text = File(session.filePath!).readAsStringSync();
    expect('Bad state: in build'.allMatches(text), hasLength(1));
  });
}
