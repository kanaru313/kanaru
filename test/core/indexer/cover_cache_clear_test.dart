import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/cover_cache_clear.dart';
import 'package:kanaru/core/indexer/cover_paths.dart';

String _hash(String c) => c * 64;

void main() {
  late Directory root;
  late String covers;
  late String current;

  setUp(() {
    root = Directory.systemTemp.createTempSync('kanaru-cover-clear');
    covers = '${root.path}/covers';
    current = '$covers/512';
  });
  tearDown(() => root.deleteSync(recursive: true));

  File thumbnail(String size, String c) {
    final shard = c * 2;
    return File('$covers/$size/$shard/${_hash(c)}.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
  }

  final later = DateTime.now().add(const Duration(minutes: 1));

  test('deletes the thumbnails and temp files of every size folder', () async {
    final a = thumbnail('512', 'a');
    final b = thumbnail('512', 'b');
    final temp = File('$current/aa/${coverTempPrefix}123')
      ..writeAsBytesSync([1]);
    final old = thumbnail('256', 'c');

    final deleted = await clearCoverCache(current, before: later);

    expect(deleted, 4);
    for (final f in [a, b, temp, old]) {
      expect(f.existsSync(), isFalse, reason: f.path);
    }
    expect(Directory('$current/aa').existsSync(), isFalse, reason: 'empty');
    expect(Directory(current).existsSync(), isTrue, reason: 'kept');
    expect(Directory('$covers/256').existsSync(), isFalse, reason: 'old size');
  });

  test('leaves files that are not thumbnails alone', () async {
    thumbnail('512', 'a');
    final stray = File('$current/aa/notes.txt')..writeAsStringSync('x');
    final top = File('$current/readme')..writeAsStringSync('x');
    final otherFolder = File('$covers/custom/aa/${_hash('a')}.jpg')
      ..createSync(recursive: true);
    final badShard = File('$current/zz/${_hash('a')}.jpg')
      ..createSync(recursive: true);

    final deleted = await clearCoverCache(current, before: later);

    expect(deleted, 1);
    for (final f in [stray, top, otherFolder, badShard]) {
      expect(f.existsSync(), isTrue, reason: f.path);
    }
    expect(Directory('$current/aa').existsSync(), isTrue, reason: 'not empty');
  });

  test('keeps thumbnails written after the clear started', () async {
    final fresh = thumbnail('512', 'a');
    final before = DateTime.now().subtract(const Duration(minutes: 1));

    expect(await clearCoverCache(current, before: before), 0);
    expect(fresh.existsSync(), isTrue);
  });

  test('never follows links', () async {
    final outside = Directory('${root.path}/elsewhere/aa')
      ..createSync(recursive: true);
    final victim = File('${outside.path}/${_hash('a')}.jpg')
      ..writeAsBytesSync([1]);
    Directory(current).createSync(recursive: true);
    Link('$current/aa').createSync(outside.path);
    Link('$covers/1024').createSync('${root.path}/elsewhere');

    expect(await clearCoverCache(current, before: later), 0);
    expect(victim.existsSync(), isTrue);
  });

  test('a missing covers folder counts as empty', () async {
    expect(await clearCoverCache(current, before: later), 0);
  });
}
