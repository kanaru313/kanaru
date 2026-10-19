import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_startup.dart';

void main() {
  late Directory tmp;
  late Map<String, String> env;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kanaru_library_test');
    env = {'XDG_DATA_HOME': tmp.path};
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  File dbFile() => File('${tmp.path}/kanaru/library.db');

  test('without HOME the database is unavailable', () async {
    final result = await openLibraryAtStartup({});
    expect(result.db, isNull);
    expect(result.error, isNotNull);
    expect(result.hasRoots, isFalse);
  });

  test('a fresh data directory opens an empty WAL database', () async {
    final result = await openLibraryAtStartup(env);
    addTearDown(() => result.db?.close());
    expect(result.error, isNull);
    expect(result.hasRoots, isFalse);
    expect(dbFile().existsSync(), isTrue);
    final mode = await result.db!
        .customSelect('PRAGMA journal_mode')
        .getSingle();
    expect(mode.data.values.single, 'wal');
    final fk = await result.db!.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.single, 1);
  });

  test('a garbage library.db gives no database and does not throw', () async {
    dbFile()
      ..createSync(recursive: true)
      ..writeAsStringSync('this is not a sqlite file' * 20);
    final result = await openLibraryAtStartup(env);
    expect(result.db, isNull);
    expect(result.error, isNotNull);
    expect(dbFile().existsSync(), isTrue, reason: 'the file is left alone');
  });

  test('a directory named library.db gives no database', () async {
    dbFile().createSync(recursive: true);
    dbFile().deleteSync();
    Directory(dbFile().path).createSync();
    final result = await openLibraryAtStartup(env);
    expect(result.db, isNull);
    expect(result.error, isNotNull);
  });

  test('a stored root is reported on the next start', () async {
    final first = await openLibraryAtStartup(env);
    await first.db!.addRoots(['/music'], now: 1);
    await first.db!.close();

    final second = await openLibraryAtStartup(env);
    addTearDown(() => second.db?.close());
    expect(second.hasRoots, isTrue);
    expect(second.overrides, hasLength(2));
  });
}
