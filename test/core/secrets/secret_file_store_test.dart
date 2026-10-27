import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/paths/app_directories.dart';
import 'package:kanaru/core/secrets/secret_file_store.dart';
import 'package:kanaru/core/secrets/secret_store.dart';

void main() {
  late Directory root;
  late String dataDir;
  late String path;

  setUp(() {
    root = Directory.systemTemp.createTempSync('kanaru_secrets_');
    dataDir = resolveDataDirectory({'XDG_DATA_HOME': root.path})!;
    path = '$dataDir/secrets.json';
  });

  tearDown(() => root.deleteSync(recursive: true));

  int modeBits(String p) => FileStat.statSync(p).mode & 0x1FF;

  test('lives in <XDG_DATA_HOME>/kanaru/secrets.json', () async {
    await SecretFileStore(dataDir).write('a', '1');

    expect(path, endsWith('kanaru/secrets.json'));
    expect(File(path).existsSync(), isTrue);
  });

  test('a new file is 0600 and no temp file is left', () async {
    await SecretFileStore(dataDir).write('a', '1');

    expect(modeBits(path), 384);
    expect(Directory(dataDir).listSync().map((e) => e.path), [path]);
  });

  test('a missing file reads as null', () async {
    expect(await SecretFileStore(dataDir).read('a'), isNull);
    expect(Directory(dataDir).existsSync(), isFalse);
  });

  test('write then read round-trips, and other keys survive', () async {
    final store = SecretFileStore(dataDir);
    await store.write('a', '1');
    await store.write('b', '2');
    await store.write('a', '3');

    expect(await store.read('a'), '3');
    expect(await store.read('b'), '2');
  });

  test('deleting the last key removes the file', () async {
    final store = SecretFileStore(dataDir);
    await store.write('a', '1');
    await store.write('b', '2');
    await store.delete('a');
    expect(File(path).existsSync(), isTrue);
    await store.delete('b');

    expect(File(path).existsSync(), isFalse);
    await store.delete('b');
  });

  test('stale temp files are swept on load', () async {
    Directory(dataDir).createSync(recursive: true);
    final stale = File('$path.123.tmp')..writeAsStringSync('secret');
    final other = File('$dataDir/settings.json')..writeAsStringSync('{}');

    expect(await SecretFileStore(dataDir).read('a'), isNull);

    expect(stale.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
  });

  test('invalid JSON reads as null', () async {
    Directory(dataDir).createSync(recursive: true);
    File(path).writeAsStringSync('{not json');
    Process.runSync('chmod', ['600', path]);

    expect(await SecretFileStore(dataDir).read('a'), isNull);
  });

  test('a file open to others is tightened on read and reported', () async {
    Directory(dataDir).createSync(recursive: true);
    File(path).writeAsStringSync(jsonEncode({'a': '1'}));
    Process.runSync('chmod', ['644', path]);
    final store = SecretFileStore(dataDir);

    expect(await store.read('a'), '1');

    expect(modeBits(path), 384);
    expect(store.modeWasFixed, isTrue);
  });

  test('a file that is already private is not reported', () async {
    final store = SecretFileStore(dataDir);
    await store.write('a', '1');
    await store.read('a');

    expect(store.modeWasFixed, isFalse);
  });

  test('a failing chmod aborts the write and leaves nothing behind', () async {
    final store = SecretFileStore(dataDir, chmod: (_) async {});

    await expectLater(
      store.write('a', 'top-secret'),
      throwsA(
        isA<SecretStoreException>()
            .having((e) => e.kind, 'kind', SecretStoreFailure.io)
            .having((e) => e.toString(), 'text', isNot(contains('top-secret'))),
      ),
    );

    expect(Directory(dataDir).listSync(), isEmpty);
  });

  test('a symbolic link is not chmodded through', () async {
    Directory(dataDir).createSync(recursive: true);
    final target = File('${root.path}/target.json')
      ..writeAsStringSync(jsonEncode({'a': '1'}));
    Process.runSync('chmod', ['644', target.path]);
    Link(path).createSync(target.path);
    final store = SecretFileStore(dataDir);

    expect(await store.read('a'), '1');

    expect(modeBits(target.path), 420);
    expect(store.modeWasFixed, isFalse);
  });

  test(
    'writing replaces a symbolic link and leaves its target alone',
    () async {
      Directory(dataDir).createSync(recursive: true);
      final target = File('${root.path}/target.json')..writeAsStringSync('{}');
      Link(path).createSync(target.path);

      await SecretFileStore(dataDir).write('a', '1');

      expect(FileSystemEntity.isLinkSync(path), isFalse);
      expect(target.readAsStringSync(), '{}');
    },
  );

  test('deleting with a malformed file removes it', () async {
    Directory(dataDir).createSync(recursive: true);
    File(path).writeAsStringSync('[1, 2');
    Process.runSync('chmod', ['600', path]);

    await SecretFileStore(dataDir).delete('a');

    expect(File(path).existsSync(), isFalse);
  });
}
