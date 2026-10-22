import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/session/playback_session.dart';
import 'package:kanaru/core/player/session/playback_session_file.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_file.dart';

void main() {
  late Directory root;
  late String path;

  setUp(() {
    root = Directory.systemTemp.createTempSync('kanaru_session_');
    path = '${root.path}/config/playback-session.json';
  });

  tearDown(() {
    // Restore access so mode-000 entries do not block the cleanup.
    Process.runSync('chmod', ['-R', 'u+rwx', root.path]);
    root.deleteSync(recursive: true);
  });

  void writeFile(String content) {
    File(path).parent.createSync(recursive: true);
    File(path).writeAsStringSync(content);
  }

  const a = Track(uri: '/music/a.flac', title: 'A');
  const b = Track(uri: '/music/b.flac', title: 'B');
  const first = PlaybackSession(
    tracks: [a, b],
    order: [0, 1],
    index: 1,
    position: Duration(seconds: 83),
    volume: 40,
  );
  const second = PlaybackSession(tracks: [a], order: [0], volume: 90);

  test('no file loads nothing and stays writable', () {
    final file = PlaybackSessionFile(path);

    expect(file.load(), isNull);
    expect(file.readOnly, isFalse);
  });

  test('saves then loads', () async {
    expect(await PlaybackSessionFile(path).save(first), isTrue);

    expect(PlaybackSessionFile(path).load(), first);
  });

  test('a save leaves valid JSON and no temporary file', () async {
    final file = PlaybackSessionFile(path);
    await file.save(first);
    await file.save(second);

    final json = jsonDecode(File(path).readAsStringSync());
    expect(json, isA<Map<String, Object?>>());
    expect((json as Map)['version'], 1);
    final names = File(path).parent.listSync().map((e) => e.path);
    expect(names.where((name) => name.endsWith('.tmp')), isEmpty);
  });

  test('quick saves end with the newest snapshot on disk', () async {
    final file = PlaybackSessionFile(path);
    final saves = [file.save(first), file.save(second), file.save(first)];
    file.save(second);
    await Future.wait(saves);
    await file.flush();

    expect(PlaybackSessionFile(path).load(), second);
  });

  test('load after save returns the saved snapshot from memory', () async {
    writeFile('{"version": 1}');
    final file = PlaybackSessionFile(path);
    final saving = file.save(second);

    expect(file.load(), second);
    expect(file.latest, second);
    await saving;
  });

  test('load reads the disk only once', () async {
    final file = PlaybackSessionFile(path);
    await PlaybackSessionFile(path).save(first);
    expect(file.load(), first);

    File(path).deleteSync();
    expect(file.load(), first);
  });

  group('a file that is not a valid session', () {
    void expectQuarantined() {
      final file = PlaybackSessionFile(path);

      expect(file.load(), isNull);
      expect(file.readOnly, isFalse);
      expect(File('$path.invalid').existsSync(), isTrue);
      expect(File(path).existsSync(), isFalse);
    }

    test('broken JSON is moved aside', () {
      writeFile('{"version": 1, "tracks": ');
      expectQuarantined();
    });

    test('JSON that is not an object is moved aside', () {
      writeFile('[1, 2]');
      expectQuarantined();
    });

    test('a session that fails validation is moved aside', () {
      writeFile(
        jsonEncode({
          'version': 1,
          'tracks': <Object>[],
          'order': [3],
          'index': 0,
          'shuffled': false,
          'repeat': 'off',
          'positionMs': 0,
          'volume': 100,
        }),
      );
      expectQuarantined();
    });

    test('a file without a version is moved aside', () {
      writeFile('{"tracks": []}');
      expectQuarantined();
    });

    test('bytes that are not UTF-8 are moved aside', () {
      File(path).parent.createSync(recursive: true);
      File(path).writeAsBytesSync([0xff, 0xfe, 0x00]);
      expectQuarantined();
    });
  });

  test('a newer version is not restored and never overwritten', () async {
    writeFile('{"version": 2, "fromTheFuture": true}');
    final before = File(path).readAsBytesSync();
    final file = PlaybackSessionFile(path);

    expect(file.load(), isNull);
    expect(file.readOnly, isTrue);
    expect(await file.save(first), isTrue);
    expect(File(path).readAsBytesSync(), before);
    expect(File('$path.invalid').existsSync(), isFalse);
  });

  test('an unreadable file is not overwritten', () async {
    await PlaybackSessionFile(path).save(first);
    final before = File(path).readAsBytesSync();
    Process.runSync('chmod', ['000', path]);
    final file = PlaybackSessionFile(path);

    expect(file.load(), isNull);
    expect(file.readOnly, isTrue);
    await file.save(second);

    Process.runSync('chmod', ['644', path]);
    expect(File(path).readAsBytesSync(), before);
  });

  test('a save into a read-only directory returns false', () async {
    Directory(File(path).parent.path).createSync(recursive: true);
    Process.runSync('chmod', ['555', File(path).parent.path]);
    final file = PlaybackSessionFile(path);

    expect(await file.save(first), isFalse);
    expect(File(path).existsSync(), isFalse);
  });

  group('playbackSessionFileFor', () {
    test('sits next to the settings file', () {
      final file = playbackSessionFileFor(
        SettingsFile('${root.path}/settings.json'),
      );

      expect(file?.path, '${root.path}/playback-session.json');
    });

    test('is null without a settings file', () {
      expect(playbackSessionFileFor(null), isNull);
    });
  });

  group('cover keys', () {
    const dir = '/cache/covers/512';
    final key = 'ab/${'ab'.padRight(64, '0')}.jpg';
    final thumb = Track(uri: '/music/t.flac', title: 'T', artUri: '$dir/$key');
    final session = PlaybackSession(tracks: [thumb], order: const [0]);

    test('the saved file holds the key, not the path', () async {
      await PlaybackSessionFile(path, coverDirectory: dir).save(session);

      final text = File(path).readAsStringSync();
      expect(text, contains('"coverKey":"$key"'));
      expect(text, isNot(contains(dir)));
    });

    test('a load with the same folder gives the path back', () async {
      await PlaybackSessionFile(path, coverDirectory: dir).save(session);

      final loaded = PlaybackSessionFile(path, coverDirectory: dir).load();
      expect(loaded?.tracks.single.artUri, '$dir/$key');
    });

    test('playbackSessionFileFor passes the folder on', () {
      final file = playbackSessionFileFor(
        SettingsFile('${root.path}/settings.json'),
        coverDirectory: dir,
      );

      expect(file?.coverDirectory, dir);
    });
  });
}
