import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_missing_roots.dart';
import 'package:kanaru/core/database/library_database.dart';

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<String>> missing(Set<String> existing) =>
      missingRootPaths(db, (path) async => existing.contains(path));

  test('no roots: nothing is missing', () async {
    expect(await missing({}), isEmpty);
  });

  test('every root exists: nothing is missing', () async {
    await db.addRoots(['/a', '/b'], now: 1);
    expect(await missing({'/a', '/b'}), isEmpty);
  });

  test('one missing root is named', () async {
    await db.addRoots(['/a', '/b'], now: 1);
    expect(await missing({'/a'}), ['/b']);
  });

  test('several missing roots come in root id order', () async {
    await db.addRoots(['/z', '/a', '/m'], now: 1);
    expect(await missing({'/a'}), ['/z', '/m']);
  });

  test('a check that throws counts as present', () async {
    await db.addRoots(['/a', '/b'], now: 1);
    final result = await missingRootPaths(db, (path) async {
      if (path == '/a') throw const FormatException('denied');
      return false;
    });
    expect(result, ['/b']);
  });
}
