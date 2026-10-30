import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_failure_log.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_fetch_bridge.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_log.dart';
import 'package:logging/logging.dart';

PluginRunLogEvent _event({
  String installId = 'plugin-aaaaaaaaaaaa',
  String kind = 'network',
  String message = 'failed',
  String? stack = 'search.js:3',
  List<String> console = const ['line one'],
  Object? query,
  List<PluginRequestRecord> requests = const [],
}) => PluginRunLogEvent(
  time: DateTime.utc(2026, 10, 30, 12, 0, 1),
  installId: installId,
  pluginName: 'My Plugin',
  version: '1.2.0',
  script: 'search.js',
  query: query ?? {'title': 'Song', 'artist': 'Artist'},
  kind: kind,
  message: message,
  stack: stack,
  console: console,
  requests: requests,
);

void main() {
  late Directory dir;
  late List<LogRecord> records;
  late StreamSubscription<LogRecord> sub;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('plugin_run_log_test');
    records = [];
    Logger.root.level = Level.ALL;
    sub = Logger.root.onRecord.listen(records.add);
  });
  tearDown(() async {
    await sub.cancel();
    dir.deleteSync(recursive: true);
  });

  List<Map<String, Object?>> lines(String name) =>
      File('${dir.path}/$name')
          .readAsLinesSync()
          .map((l) => jsonDecode(l) as Map<String, Object?>)
          .toList();

  test('a failed run is one JSON line with every field', () async {
    final log = PluginRunLog(dir);
    await log.write(
      _event(
        requests: const [
          PluginRequestRecord(
            method: 'GET',
            host: 'api.example.org',
            path: '/v1/search',
            status: 500,
            ms: 12,
          ),
        ],
      ),
    );

    final event = lines('plugin-aaaaaaaaaaaa.jsonl').single;
    expect(event, {
      'ts': '2026-10-30T12:00:01.000Z',
      'installId': 'plugin-aaaaaaaaaaaa',
      'pluginName': 'My Plugin',
      'version': '1.2.0',
      'script': 'search.js',
      'query': {'title': 'Song', 'artist': 'Artist'},
      'kind': 'network',
      'message': 'failed',
      'stack': 'search.js:3',
      'console': ['line one'],
      'requests': [
        {
          'method': 'GET',
          'host': 'api.example.org',
          'path': '/v1/search',
          'status': 500,
          'ms': 12,
        },
      ],
    });
  });

  test('events are appended, one per line', () async {
    final log = PluginRunLog(dir);
    await log.write(_event(message: 'a'));
    await log.write(_event(message: 'b'));
    expect(lines('plugin-aaaaaaaaaaaa.jsonl').map((e) => e['message']), [
      'a',
      'b',
    ]);
  });

  test('a clean run writes nothing, one that printed is written', () async {
    final log = PluginRunLog(dir);
    await log.write(_event(kind: pluginRunOkKind, console: const []));
    expect(File('${dir.path}/plugin-aaaaaaaaaaaa.jsonl').existsSync(), isFalse);

    await log.write(_event(kind: pluginRunOkKind, stack: null));
    expect(lines('plugin-aaaaaaaaaaaa.jsonl').single['kind'], 'ok');
  });

  group('config values', () {
    test(
      'of 4+ characters are hidden in message, stack, console, path',
      () async {
        final log = PluginRunLog(dir);
        await log.write(
          _event(
            message: 'bad key sk-12345 for user',
            stack: 'at sk-12345 (search.js:1)',
            console: const ['key=sk-12345', 'other pass1234'],
            requests: const [
              PluginRequestRecord(
                method: 'GET',
                host: 'h.example.org',
                path: '/sk-12345/x',
                status: null,
                ms: 1,
              ),
            ],
          ),
          config: {'apiKey': 'sk-12345', 'pw': 'pass1234'},
        );

        final text = File('${dir.path}/plugin-aaaaaaaaaaaa.jsonl')
            .readAsStringSync();
        expect(text, isNot(contains('sk-12345')));
        expect(text, isNot(contains('pass1234')));
        final event = lines('plugin-aaaaaaaaaaaa.jsonl').single;
        expect(event['message'], 'bad key *** for user');
        expect(event['stack'], 'at *** (search.js:1)');
        expect(event['console'], ['key=***', 'other ***']);
      },
    );

    test('shorter than 4 characters are left alone', () async {
      await PluginRunLog(dir)
          .write(_event(message: 'abc ok'), config: {'a': 'abc', 'b': ''});
      expect(lines('plugin-aaaaaaaaaaaa.jsonl').single['message'], 'abc ok');
    });

    test('a value inside a longer one hides the longer one first', () async {
      await PluginRunLog(dir).write(
        _event(message: 'token abcdefgh'),
        config: {'short': 'abcd', 'long': 'abcdefgh'},
      );
      expect(lines('plugin-aaaaaaaaaaaa.jsonl').single['message'], 'token ***');
    });
  });

  group('rotation', () {
    test('the file moves to .1 before it passes the limit', () async {
      final log = PluginRunLog(dir, maxBytes: 1000);
      for (var i = 0; i < 12; i++) {
        await log.write(_event(message: 'm$i ${'x' * 150}'));
      }
      final main = File('${dir.path}/plugin-aaaaaaaaaaaa.jsonl');
      final old = File('${dir.path}/plugin-aaaaaaaaaaaa.jsonl.1');
      expect(old.existsSync(), isTrue);
      expect(main.lengthSync(), lessThanOrEqualTo(1000));
      expect(old.lengthSync(), lessThanOrEqualTo(1000));
      // Newest events are in the main file, in order.
      final messages = lines('plugin-aaaaaaaaaaaa.jsonl')
          .map((e) => e['message'] as String);
      expect(messages.last, startsWith('m11 '));
    });

    test('the old .1 is replaced, not kept', () async {
      final log = PluginRunLog(dir, maxBytes: 600);
      for (var i = 0; i < 30; i++) {
        await log.write(_event(message: 'n$i ${'y' * 200}'));
      }
      final oldMessages = lines('plugin-aaaaaaaaaaaa.jsonl.1')
          .map((e) => e['message'] as String);
      expect(oldMessages.first, isNot(startsWith('n0 ')));
      expect(
        Directory(dir.path)
            .listSync()
            .map((e) => e.path.split('/').last)
            .toSet(),
        {'plugin-aaaaaaaaaaaa.jsonl', 'plugin-aaaaaaaaaaaa.jsonl.1'},
      );
    });

    test('the default limit is 512 KiB', () {
      expect(pluginRunLogMaxBytes, 512 * 1024);
      expect(PluginRunLog(dir).maxBytes, 512 * 1024);
    });
  });

  test('concurrent writes of one file all land, whole lines', () async {
    final log = PluginRunLog(dir);
    await Future.wait([
      for (var i = 0; i < 40; i++) log.write(_event(message: 'c$i')),
      for (var i = 0; i < 40; i++)
        PluginRunLog(dir).write(_event(message: 'd$i')),
    ]);
    expect(lines('plugin-aaaaaaaaaaaa.jsonl'), hasLength(80));
  });

  test('plugins have their own files', () async {
    final log = PluginRunLog(dir);
    await log.write(_event(installId: 'plugin-bbbbbbbbbbbb'));
    await log.write(_event(installId: 'plugin-cccccccccccc'));
    expect(File('${dir.path}/plugin-bbbbbbbbbbbb.jsonl').existsSync(), isTrue);
    expect(File('${dir.path}/plugin-cccccccccccc.jsonl').existsSync(), isTrue);
  });

  test('an install id that is not a plain file name writes nothing', () async {
    final log = PluginRunLog(dir);
    for (final id in ['../evil', 'a/b', '.hidden', '', 'inst-1']) {
      await log.write(_event(installId: id));
    }
    expect(dir.listSync(), isEmpty);
    expect(log.fileOf('../evil'), isNull);
  });

  group('a write failure', () {
    late PluginRunLog broken;

    setUp(() {
      // The directory would have to live below a regular file.
      final blocker = File('${dir.path}/blocker')..writeAsStringSync('x');
      broken = PluginRunLog(Directory('${blocker.path}/logs'));
    });

    test('is swallowed', () async {
      await expectLater(broken.write(_event()), completes);
    });

    test('is logged once, with no path and no values', () async {
      await broken.write(_event(message: 'secret-text', query: 'my-song'));
      await broken.write(_event());
      final warnings = records.where((r) => r.level >= Level.WARNING).toList();
      expect(warnings, hasLength(1));
      expect(warnings.single.loggerName, 'lyrics_plugin');
      final text = '${warnings.single.message} ${warnings.single.error}';
      expect(text, isNot(contains(dir.path)));
      expect(text, isNot(contains('secret-text')));
      expect(text, isNot(contains('my-song')));
    });
  });

  group('encoded config values', () {
    test('are hidden in the percent-encoded forms of a URL path', () async {
      await PluginRunLog(dir).write(
        _event(
          message: 'my%20key and a%7Cb%5Ec and my key',
          requests: const [
            PluginRequestRecord(
              method: 'GET',
              host: 'h.example.org',
              path: '/v1/my%20key/a%7Cb%5Ec',
              status: null,
              ms: 1,
            ),
          ],
        ),
        config: {'one': 'my key', 'two': 'a|b^c'},
      );
      final text = File('${dir.path}/plugin-aaaaaaaaaaaa.jsonl')
          .readAsStringSync();
      for (final form in ['my key', 'my%20key', 'a|b^c', 'a%7Cb%5Ec']) {
        expect(text, isNot(contains(form)));
      }
      expect(
        lines('plugin-aaaaaaaaaaaa.jsonl').single['message'],
        '*** and *** and ***',
      );
    });
  });

  group('deleteLogs', () {
    test('removes the file and the rotated one', () async {
      final log = PluginRunLog(dir, maxBytes: 600);
      for (var i = 0; i < 10; i++) {
        await log.write(_event(message: 'z$i ${'q' * 200}'));
      }
      expect(
        File('${dir.path}/plugin-aaaaaaaaaaaa.jsonl.1').existsSync(),
        isTrue,
      );
      await log.deleteLogs('plugin-aaaaaaaaaaaa');
      expect(dir.listSync(), isEmpty);
    });

    test(
      'writes already queued are dropped and cannot bring the file back',
      () async {
        final log = PluginRunLog(dir);
        final writes = [
          for (var i = 0; i < 5; i++) log.write(_event(message: 'w$i')),
        ];
        await log.deleteLogs('plugin-aaaaaaaaaaaa');
        await Future.wait(writes);
        expect(dir.listSync(), isEmpty);
      },
    );

    test(
      'writes queued before the delete are dropped, later ones kept',
      () async {
        final log = PluginRunLog(dir);
        final before = log.write(_event(message: 'before'));
        final deleted = log.deleteLogs('plugin-aaaaaaaaaaaa');
        // A revived plugin keeps its id and logs again at once, with no call
        // to reopen it.
        final after = log.write(_event(message: 'after'));
        await Future.wait([before, deleted, after]);

        expect(lines('plugin-aaaaaaaaaaaa.jsonl').map((l) => l['message']), [
          'after',
        ]);
      },
    );

    test('other plugins are not affected', () async {
      final log = PluginRunLog(dir);
      await log.write(_event(installId: 'plugin-bbbbbbbbbbbb'));
      await log.deleteLogs('plugin-aaaaaaaaaaaa');
      expect(
        File('${dir.path}/plugin-bbbbbbbbbbbb.jsonl').existsSync(),
        isTrue,
      );
    });

    test('a missing file or a bad id is no error', () async {
      final log = PluginRunLog(dir);
      await expectLater(log.deleteLogs('plugin-eeeeeeeeeeee'), completes);
      await expectLater(log.deleteLogs('../x'), completes);
    });
  });

  test('a run that ended abandoned is not written', () async {
    await PluginRunLog(dir).write(_event(kind: 'abandoned'));
    expect(dir.listSync(), isEmpty);
  });

  group('app log line', () {
    test('has the plugin, id, script, kind and a blocked host only', () {
      logPluginFailure(
        pluginName: 'My Plugin',
        installId: 'plugin-aaaaaaaaaaaa',
        script: 'search.js',
        kind: 'blockedHost',
        blockedHost: 'evil.example.net',
      );
      final record = records.single;
      expect(record.loggerName, 'lyrics_plugin');
      expect(record.level, Level.INFO);
      expect(record.message, contains('My Plugin'));
      expect(record.message, contains('plugin-aaaaaaaaaaaa'));
      expect(record.message, contains('search.js'));
      expect(record.message, contains('blockedHost'));
      expect(record.message, contains('evil.example.net'));
      expect(record.error, isNull);
    });

    test('has no host when none was blocked, and no control characters', () {
      final line = pluginFailureLogLine(
        pluginName: 'Bad\nName',
        installId: 'plugin-dddddddddddd',
        script: 'lyrics.js',
        kind: 'network',
      );
      expect(line, isNot(contains('host=')));
      expect(line, isNot(contains('\n')));
    });

    test(
      'writing a failed run adds no song data or console text to any log',
      () async {
        await PluginRunLog(dir).write(
          _event(
            query: {
              'title': 'Secret Title',
              'artist': 'Secret Artist',
              'album': 'Secret Album',
            },
            console: const ['console text here'],
            stack: 'stack text here',
            requests: const [
              PluginRequestRecord(
                method: 'GET',
                host: 'h.example.org',
                path: '/private/path',
                status: 200,
                ms: 1,
              ),
            ],
          ),
        );
        logPluginFailure(
          pluginName: 'My Plugin',
          installId: 'plugin-aaaaaaaaaaaa',
          script: 'search.js',
          kind: 'network',
        );
        final all = records.map((r) => '${r.message} ${r.error}').join('\n');
        for (final text in [
          'Secret Title',
          'Secret Artist',
          'Secret Album',
          'console text here',
          'stack text here',
          '/private/path',
          dir.path,
        ]) {
          expect(all, isNot(contains(text)));
        }
      },
    );
  });
}
