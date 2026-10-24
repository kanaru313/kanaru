import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/search/search_fields.dart';
import 'package:kanaru/core/search/search_prefs.dart';
import 'package:kanaru/core/search/search_prefs_file.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kanaru_search_prefs');
    path = '${dir.path}/search_history.json';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Map<String, Object?> readJson() =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

  test('no file gives the defaults', () async {
    final prefs = await SearchPrefsFile(path).load();
    expect(prefs.history, isEmpty);
    expect(prefs.fields, defaultSearchFields);
  });

  test('save then load round-trips', () async {
    final file = SearchPrefsFile(path);
    await file.save(
      const SearchPrefs().record('a').record('b').withFields({
        SearchField.title,
        SearchField.comment,
      }),
    );
    expect(readJson()['version'], 1);
    final loaded = await SearchPrefsFile(path).load();
    expect(loaded.history, ['b', 'a']);
    expect(loaded.fields, {SearchField.title, SearchField.comment});
  });

  test('creates the folder and leaves no temporary file', () async {
    final nested = '${dir.path}/deep/er/search_history.json';
    await SearchPrefsFile(nested).save(const SearchPrefs().record('a'));
    expect(File(nested).existsSync(), isTrue);
    final names = Directory(File(nested).parent.path)
        .listSync()
        .map((e) => e.path)
        .toList();
    expect(names.where((n) => n.endsWith('.tmp')), isEmpty);
  });

  test('quick saves land in order', () async {
    final file = SearchPrefsFile(path);
    var prefs = const SearchPrefs();
    final saves = <Future<void>>[];
    for (var i = 0; i < 10; i++) {
      prefs = prefs.record('q$i');
      saves.add(file.save(prefs));
    }
    await Future.wait(saves);
    expect((await SearchPrefsFile(path).load()).history.first, 'q9');
  });

  test('broken JSON is moved aside and defaults are used', () async {
    File(path).writeAsStringSync('{ not json');
    final file = SearchPrefsFile(path);
    expect((await file.load()).history, isEmpty);
    expect(File(path).existsSync(), isFalse);
    expect(File('$path.invalid').readAsStringSync(), '{ not json');
    expect(file.readOnly, isFalse);
  });

  test('JSON that is not an object is moved aside', () async {
    File(path).writeAsStringSync('[1, 2]');
    expect((await SearchPrefsFile(path).load()).history, isEmpty);
    expect(File('$path.invalid').existsSync(), isTrue);
  });

  test('wrong types give defaults without crashing', () async {
    File(path).writeAsStringSync(
      jsonEncode({'version': 'x', 'history': 'nope', 'fields': 5}),
    );
    final prefs = await SearchPrefsFile(path).load();
    expect(prefs.history, isEmpty);
    expect(prefs.fields, defaultSearchFields);
  });

  test('unknown fields and bad history entries are dropped', () async {
    File(path).writeAsStringSync(
      jsonEncode({
        'version': 1,
        'history': ['ok', 3, '   ', 'OK', 'b' * 900, null],
        'fields': ['title', 'lyrics', 7, 'genre'],
      }),
    );
    final prefs = await SearchPrefsFile(path).load();
    expect(prefs.history, ['ok', 'b' * searchHistoryEntryMaxLength]);
    expect(prefs.fields, {SearchField.title, SearchField.genre});
  });

  test('only unknown fields fall back to the defaults', () async {
    File(path).writeAsStringSync(
      jsonEncode({
        'history': ['a'],
        'fields': ['lyrics'],
      }),
    );
    final prefs = await SearchPrefsFile(path).load();
    expect(prefs.fields, defaultSearchFields);
    expect(prefs.history, ['a']);
  });

  test('keeps at most 20 history entries when reading', () async {
    File(path).writeAsStringSync(
      jsonEncode({
        'history': [for (var i = 0; i < 30; i++) 'q$i'],
      }),
    );
    final prefs = await SearchPrefsFile(path).load();
    expect(prefs.history, hasLength(20));
    expect(prefs.history.first, 'q0');
  });

  test('a newer version is read but never overwritten', () async {
    final original = jsonEncode({
      'version': 99,
      'history': ['future'],
      'fields': ['album'],
    });
    File(path).writeAsStringSync(original);
    final file = SearchPrefsFile(path);
    final prefs = await file.load();
    expect(prefs.history, ['future']);
    expect(prefs.fields, {SearchField.album});
    expect(file.readOnly, isTrue);
    await file.save(prefs.record('x'));
    expect(File(path).readAsStringSync(), original);
  });

  test('saving through a symlink keeps the link', () async {
    final real = '${dir.path}/real.json';
    File(real).writeAsStringSync('{}');
    Link(path).createSync(real);
    await SearchPrefsFile(path).save(const SearchPrefs().record('a'));
    expect(FileSystemEntity.isLinkSync(path), isTrue);
    expect((jsonDecode(File(real).readAsStringSync()) as Map)['history'], [
      'a',
    ]);
  });

  test('a write failure does not throw', () async {
    // The parent "folder" is a file, so creating it fails.
    File('${dir.path}/blocker').writeAsStringSync('x');
    final file = SearchPrefsFile('${dir.path}/blocker/search_history.json');
    await file.save(const SearchPrefs().record('a'));
  });

  test('searchPrefsFileFor uses the data directory', () {
    expect(
      searchPrefsFileFor({'XDG_DATA_HOME': '/d'})?.path,
      '/d/kanaru/search_history.json',
    );
    expect(searchPrefsFileFor({}), isNull);
  });
}
