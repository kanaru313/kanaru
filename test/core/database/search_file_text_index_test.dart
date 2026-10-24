import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/search_file_text_index.dart';

FileTextRow _row(int id, String path, [String? comment]) =>
    (id: id, path: path, comment: comment);

void main() {
  group('fileNameOf', () {
    test('drops the folders and the extension', () {
      expect(fileNameOf('/m/Folder.d/Song.v2.flac'), 'Song.v2');
      expect(fileNameOf(r'C:\m\Song.mp3'), 'Song');
      expect(fileNameOf('noext'), 'noext');
    });
  });

  group('match', () {
    final index = SearchFileTextIndex.buildNow([
      _row(1, '/m/Sơn Tùng - Lạc trôi.flac'),
      _row(2, '/m/Sơn/other.flac', 'Live in Hà Nội'),
      _row(3, '/m/Đi Đu Đưa Đi.mp3', null),
    ]);

    test('folds accents and đ like the stored columns', () {
      expect(index.match(['son', 'lac'], fileName: true), [1]);
      expect(index.match(['di', 'du'], fileName: true), [3]);
    });

    test('the extension is not a word', () {
      expect(index.match(['flac'], fileName: true), isEmpty);
      expect(index.match(['mp3'], fileName: true), isEmpty);
    });

    test('folder names do not count', () {
      expect(index.match(['son'], fileName: true), [1]);
    });

    test('comment matches only when asked, and may be missing', () {
      expect(index.match(['live', 'ha'], comment: true), [2]);
      expect(index.match(['live'], fileName: true), isEmpty);
      expect(index.match(['di'], comment: true), isEmpty);
    });

    test('both fields count together', () {
      expect(index.match(['other', 'live'], fileName: true, comment: true), [
        2,
      ]);
    });

    test('no terms or no field match nothing', () {
      expect(index.match([], fileName: true), isEmpty);
      expect(index.match(['son']), isEmpty);
    });
  });

  test('load reads the tracks of a database through an isolate', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final rootId = (await db.addRoots(['/m'], now: 1)).single;
    await db.upsertTracks([
      TracksCompanion.insert(
        rootId: rootId,
        path: '/m/Hello World.flac',
        mtimeMs: 1,
        sizeBytes: 1,
        title: 'T',
        addedAt: 1,
        updatedAt: 1,
      ),
    ]);
    final index = await SearchFileTextIndex.load(db);
    expect(index.length, 1);
    expect(index.match(['wor'], fileName: true), hasLength(1));
  });
}
