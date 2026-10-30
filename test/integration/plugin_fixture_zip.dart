import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// The folder of the lyrics plugin fixtures, relative to the project root
/// (the working directory of `flutter test`).
const lyricsPluginFixtures = 'test/fixtures/lyrics_plugins';

/// Builds the plugin zip of the fixture folder [relativeFolder] (for example
/// `lrclib` or `hostile/redos`, under [lyricsPluginFixtures]) at test time,
/// so no binary zip is committed. Entry names are the paths inside the
/// folder with `/` separators; `plugin.json` is at the root of the zip.
Uint8List zipFixtureFolder(String relativeFolder) {
  final root = Directory('$lyricsPluginFixtures/$relativeFolder');
  if (!root.existsSync()) {
    throw StateError('fixture folder not found: ${root.path}');
  }
  final archive = Archive();
  final files = root.listSync(recursive: true, followLinks: false)
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final entity in files.whereType<File>()) {
    final name = entity.path
        .substring(root.path.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    archive.add(ArchiveFile.bytes(name, entity.readAsBytesSync()));
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}
