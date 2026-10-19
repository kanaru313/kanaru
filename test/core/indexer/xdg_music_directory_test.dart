import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/xdg_music_directory.dart';

void main() {
  const home = '/home/u';
  const env = {'HOME': home};
  final existing = {'/home/u/Music', '/home/u/Sounds', '/data/tunes', '/home'};
  bool isDir(String path) => existing.contains(path);

  String? suggest(String? content, [Map<String, String> e = env]) =>
      xdgMusicDirectory(e, content, isDirectory: isDir);

  test(r'expands "$HOME/…" values', () {
    expect(suggest('XDG_MUSIC_DIR="\$HOME/Sounds"'), '/home/u/Sounds');
  });

  test('accepts an absolute path and normalises it', () {
    expect(suggest('XDG_MUSIC_DIR="/data//tunes/./"'), '/data/tunes');
  });

  test('ignores comments and other keys; last assignment wins', () {
    const content = '''
# XDG_MUSIC_DIR="/data/tunes"
XDG_VIDEOS_DIR="\$HOME/Videos"
XDG_MUSIC_DIR="\$HOME/Music"
XDG_MUSIC_DIR="\$HOME/Sounds"
''';
    expect(suggest(content), '/home/u/Sounds');
  });

  test(r'falls back to $HOME/Music without a line or a file', () {
    expect(suggest(null), '/home/u/Music');
    expect(suggest('XDG_VIDEOS_DIR="\$HOME/Videos"'), '/home/u/Music');
  });

  for (final value in [
    r'$HOME',
    r'$HOME/',
    '/',
    '/home',
    'Music',
    r'$HOME/../..',
    '/data/../data/tunes',
    '',
    '/missing',
  ]) {
    test('rejects "$value" and uses the fallback', () {
      expect(suggest('XDG_MUSIC_DIR="$value"'), '/home/u/Music');
    });
  }

  test('no suggestion when the fallback is missing too', () {
    existing.remove('/home/u/Music');
    addTearDown(() => existing.add('/home/u/Music'));
    expect(suggest('XDG_MUSIC_DIR="\$HOME"'), isNull);
  });

  test('no suggestion without an absolute HOME', () {
    expect(suggest(null, const {}), isNull);
    expect(suggest(null, const {'HOME': 'home/u'}), isNull);
  });

  group('readXdgMusicDirectory', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('xdg_music'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<String?> read(String? configHome) async {
      Directory('${tmp.path}/Songs').createSync();
      return readXdgMusicDirectory({
        'HOME': tmp.path,
        'XDG_CONFIG_HOME': ?configHome,
      });
    }

    test('reads user-dirs.dirs from an absolute XDG_CONFIG_HOME', () async {
      File('${tmp.path}/cfg/user-dirs.dirs')
        ..createSync(recursive: true)
        ..writeAsStringSync('XDG_MUSIC_DIR="\$HOME/Songs"\n');
      expect(await read('${tmp.path}/cfg'), '${tmp.path}/Songs');
    });

    test('ignores a relative XDG_CONFIG_HOME and reads ~/.config', () async {
      File('${tmp.path}/.config/user-dirs.dirs')
        ..createSync(recursive: true)
        ..writeAsStringSync('XDG_MUSIC_DIR="\$HOME/Songs"\n');
      expect(await read('cfg'), '${tmp.path}/Songs');
    });

    test('a missing file gives the fallback or nothing', () async {
      expect(await read(null), isNull);
      Directory('${tmp.path}/Music').createSync();
      expect(await read(null), '${tmp.path}/Music');
    });
  });
}
