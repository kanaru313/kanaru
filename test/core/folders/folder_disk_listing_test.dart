import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/folders/folder_disk_listing.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('folder_disk_listing');
  });
  tearDown(() {
    // Unreadable test folders must be openable again to be deleted.
    Process.runSync('chmod', ['-R', 'u+rwx', root.path]);
    root.deleteSync(recursive: true);
  });

  String sub(String name) => '${root.path}/$name';
  void dir(String name) => Directory(sub(name)).createSync(recursive: true);
  void file(String name) {
    File(sub(name)).createSync(recursive: true);
  }

  List<String> names(List<String> paths) =>
      [for (final p in paths) diskEntryName(p)]..sort();

  test('hidden only: lists dot folders and dot audio files', () async {
    dir('.secret');
    dir('plain');
    file('.hidden.mp3');
    file('visible.mp3');

    final listing = await listFolderOnDisk(root.path, hiddenOnly: true);

    expect(names(listing.folders), ['.secret']);
    expect(names(listing.files), ['.hidden.mp3']);
  });

  test('everything: lists plain entries too', () async {
    dir('.secret');
    dir('plain');
    file('.hidden.flac');
    file('visible.MP3');

    final listing = await listFolderOnDisk(root.path, hiddenOnly: false);

    expect(names(listing.folders), ['.secret', 'plain']);
    expect(names(listing.files), ['.hidden.flac', 'visible.MP3']);
  });

  test('skips files that are not audio', () async {
    file('.notes.txt');
    file('.cover.jpg');
    file('.song.ogg');

    final listing = await listFolderOnDisk(root.path, hiddenOnly: true);

    expect(names(listing.files), ['.song.ogg']);
  });

  test('does not follow symlinks to folders or files', () async {
    final outside = Directory.systemTemp.createTempSync('outside');
    addTearDown(() => outside.deleteSync(recursive: true));
    File('${outside.path}/a.mp3').createSync();
    Link(sub('.linked-dir')).createSync(outside.path);
    Link(sub('.linked.mp3')).createSync('${outside.path}/a.mp3');
    dir('.real');

    final listing = await listFolderOnDisk(root.path, hiddenOnly: true);

    expect(names(listing.folders), ['.real']);
    expect(listing.files, isEmpty);
  });

  test('skips a folder holding .nomedia', () async {
    dir('.quiet');
    file('.quiet/.nomedia');
    dir('.loud');

    final listing = await listFolderOnDisk(root.path, hiddenOnly: true);

    expect(names(listing.folders), ['.loud']);
  });

  test('skips a user-excluded folder and what lies inside one', () async {
    dir('.skipped');
    dir('.kept');
    dir('.parent/deep');

    final listing = await listFolderOnDisk(
      root.path,
      hiddenOnly: true,
      excludedPaths: [sub('.skipped')],
    );
    final inside = await listFolderOnDisk(
      sub('.parent'),
      hiddenOnly: false,
      excludedPaths: [sub('.parent')],
    );

    expect(names(listing.folders), ['.kept', '.parent']);
    expect(inside.folders, isEmpty);
  });

  test('skips system folders when listing everything', () async {
    dir('lost+found');
    dir('@eaDir');
    dir(r'$RECYCLE.BIN');
    dir('Album');

    final listing = await listFolderOnDisk(root.path, hiddenOnly: false);

    expect(names(listing.folders), ['Album']);
  });

  test('skips a folder that cannot be read', () async {
    dir('.locked');
    dir('.open');
    Process.runSync('chmod', ['000', sub('.locked')]);
    // Running as root, permissions do not apply.
    if (_canRead(sub('.locked'))) {
      markTestSkipped('permissions are not enforced for this user');
      return;
    }

    final listing = await listFolderOnDisk(root.path, hiddenOnly: true);

    expect(names(listing.folders), ['.open']);
  });

  test('a missing folder gives an empty listing', () async {
    final listing = await listFolderOnDisk(sub('absent'), hiddenOnly: false);

    expect(listing.isEmpty, isTrue);
  });

  test('reads one level only', () async {
    file('.a/.b/.deep.mp3');

    final listing = await listFolderOnDisk(root.path, hiddenOnly: true);

    expect(names(listing.folders), ['.a']);
    expect(listing.files, isEmpty);
  });

  test(
    'isBrowsableDiskFolder rejects a file, a link and a missing path',
    () async {
      file('f.mp3');
      dir('real');
      Link(sub('link')).createSync(sub('real'));

      expect(await isBrowsableDiskFolder(sub('real')), isTrue);
      expect(await isBrowsableDiskFolder(sub('f.mp3')), isFalse);
      expect(await isBrowsableDiskFolder(sub('link')), isFalse);
      expect(await isBrowsableDiskFolder(sub('absent')), isFalse);
    },
  );
}

bool _canRead(String path) {
  try {
    Directory(path).listSync();
    return true;
  } on FileSystemException {
    return false;
  }
}
