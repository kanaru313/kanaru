import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/onboarding/suggested_music_folder_provider.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('suggested_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('resolves a symlinked ~/Music to the real folder', () async {
    final base = tmp.resolveSymbolicLinksSync();
    Directory('$base/data/Music').createSync(recursive: true);
    Directory('$base/home').createSync();
    Link('$base/home/Music').createSync('$base/data/Music');

    final path = await resolveSuggestedMusicFolder({
      'HOME': '$base/home',
      'XDG_CONFIG_HOME': '$base/none',
    });

    expect(path, '$base/data/Music');
  });

  test('is null without a music folder', () async {
    final path = await resolveSuggestedMusicFolder({
      'HOME': tmp.path,
      'XDG_CONFIG_HOME': '${tmp.path}/none',
    });

    expect(path, isNull);
  });
}
