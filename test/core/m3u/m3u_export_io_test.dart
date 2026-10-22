import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/m3u/m3u_export.dart';
import 'package:kanaru/core/m3u/m3u_import.dart';
import 'package:kanaru/core/m3u/m3u_write.dart';

void main() {
  late Directory tmp;
  late String root;

  String p(String relative) => '$root/$relative';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kanaru-m3u-export');
    root = await tmp.resolveSymbolicLinks();
    for (final name in ['music/a.flac', 'music/sub/b.mp3', 'music/#c.ogg']) {
      await File(p(name)).create(recursive: true);
    }
    await Directory(p('lists')).create();
  });
  tearDown(() => tmp.delete(recursive: true));

  List<M3uExportEntry> entries(List<String> names) => [
    for (final name in names) M3uExportEntry(path: p(name)),
  ];

  List<String> leftovers() => [
    for (final e in Directory(p('lists')).listSync())
      if (e.path.endsWith('.tmp')) e.path,
  ];

  test('writes absolute and relative files', () async {
    final names = ['music/a.flac', 'music/sub/b.mp3'];
    await exportM3uFile(
      p('lists/abs.m3u8'),
      entries(names),
      M3uPathStyle.absolute,
    );
    await exportM3uFile(
      p('lists/rel.m3u8'),
      entries(names),
      M3uPathStyle.relative,
    );

    expect(
      await File(p('lists/abs.m3u8')).readAsString(),
      '#EXTM3U\n${p('music/a.flac')}\n${p('music/sub/b.mp3')}\n',
    );
    expect(
      await File(p('lists/rel.m3u8')).readAsString(),
      '#EXTM3U\n../music/a.flac\n../music/sub/b.mp3\n',
    );
    expect(leftovers(), isEmpty);
  });

  test('overwrites an existing file', () async {
    await File(p('lists/x.m3u')).writeAsString('old');
    await exportM3uFile(
      p('lists/x.m3u'),
      entries(['music/a.flac']),
      M3uPathStyle.absolute,
    );
    expect(
      await File(p('lists/x.m3u')).readAsString(),
      startsWith('#EXTM3U\n'),
    );
  });

  test(
    'a symlink target keeps the link and writes the file it names',
    () async {
      await File(p('lists/real.m3u')).writeAsString('old');
      await Link(p('lists/link.m3u')).create(p('lists/real.m3u'));

      await exportM3uFile(
        p('lists/link.m3u'),
        entries(['music/a.flac']),
        M3uPathStyle.absolute,
      );

      expect(await FileSystemEntity.isLink(p('lists/link.m3u')), isTrue);
      expect(
        await File(p('lists/real.m3u')).readAsString(),
        contains('a.flac'),
      );
      expect(leftovers(), isEmpty);
    },
  );

  test(
    'relative lines start from the real folder of a symlinked one',
    () async {
      await Directory(p('deep/lists')).create(recursive: true);
      await Link(p('shortcut')).create(p('deep/lists'));

      await exportM3uFile(
        p('shortcut/p.m3u8'),
        entries(['music/a.flac']),
        M3uPathStyle.relative,
      );

      expect(
        await File(p('deep/lists/p.m3u8')).readAsString(),
        '#EXTM3U\n../../music/a.flac\n',
      );
    },
  );

  test('a file name starting with # gets ./', () async {
    await exportM3uFile(
      p('music/p.m3u8'),
      entries(['music/#c.ogg']),
      M3uPathStyle.relative,
    );
    expect(await File(p('music/p.m3u8')).readAsString(), '#EXTM3U\n./#c.ogg\n');
  });

  test('a failed write leaves no temporary file', () async {
    await expectLater(
      exportM3uFile(
        p('missing/p.m3u8'),
        entries(['music/a.flac']),
        M3uPathStyle.absolute,
      ),
      throwsA(isA<FileSystemException>()),
    );
  });

  for (final style in M3uPathStyle.values) {
    test('export then import gives the same paths (${style.name})', () async {
      final names = ['music/sub/b.mp3', 'music/#c.ogg', 'music/a.flac'];
      final target = p('lists/round.m3u8');
      await exportM3uFile(target, entries(names), style);

      final result = await importM3uFile(target);

      expect(result.paths, [for (final n in names) p(n)]);
      expect(result.unresolved, isEmpty);
      expect(result.duplicates, 0);
    });
  }

  test('a round trip merges repeats and reports missing files', () async {
    final target = p('lists/round.m3u8');
    await exportM3uFile(
      target,
      entries(['music/a.flac', 'music/a.flac', 'music/gone.flac']),
      M3uPathStyle.relative,
    );

    final result = await importM3uFile(target);

    expect(result.paths, [p('music/a.flac')]);
    expect(result.duplicates, 1);
    expect(result.unresolved.single.text, '../music/gone.flac');
  });
}
