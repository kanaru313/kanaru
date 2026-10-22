import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/folder_watcher.dart';

/// Real inotify in a temp folder: what Dart reports on Linux is what the
/// event filter was written against.
void main() {
  late Directory tmp;
  late String root;
  late FolderWatcher watcher;
  var changes = 0;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('folder_watcher_fs_test');
    root = '${tmp.resolveSymbolicLinksSync()}/music';
    Directory('$root/album').createSync(recursive: true);
    changes = 0;
    watcher = FolderWatcher(
      watch: (dir) => Directory(dir).watch(),
      onChange: () => changes++,
      maxWatches: 1000,
      quiet: const Duration(milliseconds: 150),
      maxWait: const Duration(seconds: 5),
    )..sync([root, '$root/album']);
  });
  tearDown(() async {
    await watcher.dispose();
    tmp.deleteSync(recursive: true);
  });

  // inotify needs a moment after the watch is added, and the quiet timer
  // another one after the last event.
  Future<void> pause([int ms = 600]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  test('an audio file in a watched subfolder is one change', () async {
    await pause(100);
    File('$root/album/one.flac').writeAsStringSync('x');
    File('$root/album/two.flac').writeAsStringSync('x');
    await pause();
    expect(changes, 1);
  });

  test('a cover image is no change', () async {
    await pause(100);
    File('$root/album/cover.jpg').writeAsStringSync('x');
    File('$root/album/folder.txt').writeAsStringSync('x');
    await pause();
    expect(changes, 0);
  });

  test('a file renamed to an audio name is a change', () async {
    await pause(100);
    File('$root/album/.x.flac.AbC123').writeAsStringSync('x');
    await pause();
    expect(changes, 0);
    File('$root/album/.x.flac.AbC123').renameSync('$root/album/x.flac');
    await pause();
    expect(changes, 1);
  });

  test('a subfolder moved out of the library is one change', () async {
    await pause(100);
    Directory('$root/album').renameSync('${tmp.path}/elsewhere');
    await pause();
    expect(changes, 1);
    expect(watcher.watchedCount, 1);
  });

  test('a new folder is watched at once, with its subfolders', () async {
    await pause(100);
    Directory('$root/new/disc1').createSync(recursive: true);
    await pause();
    final before = changes;
    expect(before, greaterThanOrEqualTo(1));
    expect(watcher.watchedCount, 4);
    File('$root/new/disc1/t.mp3').writeAsStringSync('x');
    await pause();
    expect(changes, before + 1);
  });

  test('a deleted subfolder is one change', () async {
    await pause(100);
    File('$root/album/a.mp3').writeAsStringSync('x');
    await pause();
    final before = changes;
    Directory('$root/album').deleteSync(recursive: true);
    await pause();
    expect(changes, before + 1);
  });
}
