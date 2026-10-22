import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/paths/local_audio_path.dart';

void main() {
  // Real folders: the helper resolves symlinks and checks the file type, so
  // the tests need a file system. `root` itself is symlink-resolved so the
  // expected paths are canonical even when the temp folder is a link.
  late String root;
  late String song;

  setUp(() async {
    final temp = await Directory.systemTemp.createTemp('local_audio_path_');
    addTearDown(() => temp.delete(recursive: true));
    root = await temp.resolveSymbolicLinks();
    await Directory('$root/music/album').create(recursive: true);
    song = '$root/music/album/01 Song.flac';
    await File(song).writeAsString('x');
  });

  group('accepts', () {
    test('an absolute path to an audio file', () async {
      expect(await localAudioPath(song), song);
    });

    test('an upper-case extension', () async {
      final loud = '$root/music/album/02.MP3';
      await File(loud).writeAsString('x');
      expect(await localAudioPath(loud), loud);
    });

    test('a file URI, percent-decoded', () async {
      final uri = Uri.file(song).toString();
      expect(uri, contains('%20'));
      expect(await localAudioPath(uri), song);
    });

    test('a file URI with localhost as host', () async {
      final uri = Uri.file(song)
          .toString()
          .replaceFirst('file://', 'file://localhost');
      expect(await localAudioPath(uri), song);
    });

    test('a file URI with non-ASCII names', () async {
      final name = '$root/music/album/Đừng Làm Trái Tim Anh Đau.opus';
      await File(name).writeAsString('x');
      expect(await localAudioPath(Uri.file(name).toString()), name);
    });

    test('a relative path against the base directory', () async {
      expect(
        await localAudioPath(
          'album/01 Song.flac',
          baseDirectory: '$root/music',
        ),
        song,
      );
      expect(
        await localAudioPath(
          './album/01 Song.flac',
          baseDirectory: '$root/music/',
        ),
        song,
      );
    });

    test('a relative name with a colon, which is not a URI', () async {
      final colon = '$root/music/album/Artist: Song.mp3';
      await File(colon).writeAsString('x');
      expect(
        await localAudioPath(
          'Artist: Song.mp3',
          baseDirectory: '$root/music/album',
        ),
        colon,
      );
    });
  });

  group('canonical spelling', () {
    test('removes . and .. and doubled slashes', () async {
      expect(
        await localAudioPath('$root/music/./album/../album//01 Song.flac'),
        song,
      );
    });

    test('resolves symlinked parent folders', () async {
      await Link('$root/link').create('$root/music');
      expect(await localAudioPath('$root/link/album/01 Song.flac'), song);
      expect(
        await localAudioPath(
          '../link/album/01 Song.flac',
          baseDirectory: '$root/music',
        ),
        song,
      );
    });

    test('keeps the name of a symlinked file, like the indexer', () async {
      final link = '$root/music/album/linked.flac';
      await Link(link).create(song);
      expect(await localAudioPath(link), link);
    });
  });

  group('rejects', () {
    for (final input in [
      'http://example.com/a.mp3',
      'https://example.com/a.flac',
      'edl://%3%/a.flac',
      'av://lavfi:sine=440',
      'av://lavfi:anoisesrc.flac',
      'ytdl://x.mp3',
      'smb://host/share/a.flac',
      'file://example.com/a.flac',
      'file://user@localhost/a.flac',
      'file:///a.flac?x=1',
      'file:///a.flac#t=1',
      'file:relative.flac',
      'FILE://other/a.flac',
      '',
    ]) {
      test('"$input"', () async {
        expect(await localAudioPath(input, baseDirectory: root), isNull);
      });
    }

    test('a URI scheme even when a matching relative file exists', () async {
      await Directory('$root/http:').create();
      await File('$root/http:/a.mp3').writeAsString('x');
      expect(await localAudioPath('http://a.mp3', baseDirectory: root), isNull);
    });

    test('a relative path without a usable base directory', () async {
      expect(await localAudioPath('music/album/01 Song.flac'), isNull);
      expect(
        await localAudioPath('album/01 Song.flac', baseDirectory: 'music'),
        isNull,
      );
    });

    test('a missing file', () async {
      expect(await localAudioPath('$root/music/album/none.flac'), isNull);
      expect(await localAudioPath('$root/none/a.flac'), isNull);
    });

    test('a folder, even with an audio-looking name', () async {
      await Directory('$root/music/folder.flac').create();
      expect(await localAudioPath('$root/music/folder.flac'), isNull);
      expect(await localAudioPath('$root/music/album/'), isNull);
      expect(await localAudioPath('$root/music/album/..'), isNull);
    });

    test('a file that is not audio', () async {
      await File('$root/music/album/cover.jpg').writeAsString('x');
      await File('$root/music/album/list.m3u').writeAsString('x');
      expect(await localAudioPath('$root/music/album/cover.jpg'), isNull);
      expect(await localAudioPath('$root/music/album/list.m3u'), isNull);
    });

    test('a broken symlink', () async {
      final link = '$root/music/album/gone.flac';
      await Link(link).create('$root/missing.flac');
      expect(await localAudioPath(link), isNull);
    });

    test('a NUL byte or an invalid percent escape', () async {
      expect(await localAudioPath('$song\u0000.flac'), isNull);
      expect(await localAudioPath('file:///a%00.flac'), isNull);
      expect(await localAudioPath('file:///a%FF.flac'), isNull);
      expect(await localAudioPath('file:///a%zz.flac'), isNull);
    });
  });
}
