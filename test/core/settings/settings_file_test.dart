import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/app_settings.dart';
import 'package:kanaru/core/settings/settings_file.dart';

void main() {
  late Directory root;
  late String path;

  setUp(() {
    root = Directory.systemTemp.createTempSync('kanaru_settings_');
    path = '${root.path}/config/settings.json';
  });

  tearDown(() {
    // Restore access so a mode-000 file does not block the cleanup.
    if (File(path).existsSync()) Process.runSync('chmod', ['644', path]);
    root.deleteSync(recursive: true);
  });

  void writeFile(String target, Object content) {
    File(target).parent.createSync(recursive: true);
    if (content is List<int>) {
      File(target).writeAsBytesSync(content);
    } else {
      File(target).writeAsStringSync(content as String);
    }
  }

  const dark = AppSettings(theme: ThemePreference.dark, languageCode: 'vi');

  test('no file gives defaults and stays writable', () {
    final file = SettingsFile(path);

    expect(file.load(), const AppSettings());
    expect(file.readOnly, isFalse);
  });

  test('saves then loads', () async {
    await SettingsFile(path).save(dark);

    expect(SettingsFile(path).load(), dark);
  });

  test('creates the parent directory', () async {
    expect(Directory('${root.path}/config').existsSync(), isFalse);

    await SettingsFile(path).save(dark);

    expect(File(path).existsSync(), isTrue);
  });

  test('overwrites an existing file and leaves no temporary file', () async {
    final file = SettingsFile(path);
    await file.save(dark);
    await file.save(const AppSettings(theme: ThemePreference.light));

    expect(
      SettingsFile(path).load(),
      const AppSettings(theme: ThemePreference.light),
    );
    final names = File(path).parent.listSync().map((e) => e.path);
    expect(names.where((name) => name.endsWith('.tmp')), isEmpty);
  });

  group('a file that is not valid settings JSON', () {
    void expectQuarantined() {
      final file = SettingsFile(path);

      expect(file.load(), const AppSettings());
      expect(file.readOnly, isFalse);
      expect(File('$path.invalid').existsSync(), isTrue);
      expect(File(path).existsSync(), isFalse);
    }

    test('broken JSON is moved aside', () {
      writeFile(path, '{"theme": ');
      expectQuarantined();
      expect(File('$path.invalid').readAsStringSync(), '{"theme": ');
    });

    test('invalid UTF-8 is moved aside', () {
      writeFile(path, [0xff, 0xfe, 0x7b, 0x7d]);
      expectQuarantined();
    });

    test('JSON that is not an object is moved aside', () {
      writeFile(path, '[1, 2]');
      expectQuarantined();
    });
  });

  test('a directory in place of the file gives read-only defaults', () async {
    Directory(path).createSync(recursive: true);
    final file = SettingsFile(path);

    expect(file.load(), const AppSettings());
    expect(file.readOnly, isTrue);

    await file.save(dark);
    expect(FileSystemEntity.isDirectorySync(path), isTrue);
  });

  test(
    'an unreadable file gives read-only defaults and is left alone',
    () async {
      writeFile(path, '{"theme": "dark"}');
      Process.runSync('chmod', ['000', path]);
      final file = SettingsFile(path);

      expect(file.load(), const AppSettings());
      expect(file.readOnly, isTrue);

      await file.save(dark);
      Process.runSync('chmod', ['644', path]);
      expect(File(path).readAsStringSync(), '{"theme": "dark"}');
    },
    skip: Platform.isLinux && _isRoot() ? 'root ignores file modes' : false,
  );

  test('a newer version is read but never overwritten', () async {
    const content = '{"version": 2, "theme": "dark", "future": 1}';
    writeFile(path, content);
    final file = SettingsFile(path);

    expect(file.load().theme, ThemePreference.dark);
    expect(file.readOnly, isTrue);

    await file.save(const AppSettings());
    expect(File(path).readAsStringSync(), content);
  });

  test('unknown keys survive a save, unless asked to drop them', () async {
    writeFile(path, '{"version": 1, "theme": "dark", "future": {"a": [1]}}');
    final file = SettingsFile(path)..load();

    await file.save(dark);
    var json = jsonDecode(File(path).readAsStringSync()) as Map;
    expect(json['future'], {
      'a': [1],
    });
    expect(json['language'], 'vi');

    await file.save(dark, keepUnknown: false);
    json = jsonDecode(File(path).readAsStringSync()) as Map;
    expect(json.containsKey('future'), isFalse);
  });

  group('symlink', () {
    late String target;

    setUp(() {
      target = '${root.path}/dotfiles/settings.json';
      File(target).parent.createSync(recursive: true);
      File(path).parent.createSync(recursive: true);
      Link(path).createSync(target, recursive: true);
    });

    test('save writes to the target and keeps the link', () async {
      writeFile(target, '{"version": 1, "theme": "light"}');
      final file = SettingsFile(path);
      expect(file.load().theme, ThemePreference.light);

      await file.save(dark);

      expect(FileSystemEntity.isLinkSync(path), isTrue);
      expect(SettingsFile(target).load(), dark);
      expect(File(target).parent.listSync().map((e) => e.path), [target]);
    });

    test(
      'invalid JSON behind a link is left untouched and read-only',
      () async {
        writeFile(target, 'not json');
        final file = SettingsFile(path);

        expect(file.load(), const AppSettings());
        expect(file.readOnly, isTrue);
        expect(FileSystemEntity.isLinkSync(path), isTrue);
        expect(File('$path.invalid').existsSync(), isFalse);

        await file.save(dark);
        expect(File(target).readAsStringSync(), 'not json');
      },
    );
  });

  test('a UTF-8 byte order mark is ignored', () {
    writeFile(path, [0xEF, 0xBB, 0xBF, ...utf8.encode('{"theme": "dark"}')]);

    final file = SettingsFile(path);

    expect(file.load().theme, ThemePreference.dark);
    expect(file.readOnly, isFalse);
    expect(File('$path.invalid').existsSync(), isFalse);
  });

  test('save reports whether it wrote the file', () async {
    final file = SettingsFile(path);
    expect(await file.save(dark), isTrue);

    // A directory where the file should go makes the rename fail.
    File(path).deleteSync();
    Directory(path).createSync();
    expect(await file.save(dark), isFalse);
    Directory(path).deleteSync();
  });
}

bool _isRoot() => Process.runSync('id', ['-u']).stdout.toString().trim() == '0';
