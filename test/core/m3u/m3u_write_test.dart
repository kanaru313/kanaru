import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/m3u/m3u_write.dart';

void main() {
  test('writes the header, EXTINF for library entries and the paths', () {
    final out = writeM3u(
      const [
        M3uExportEntry(
          path: '/m/a.flac',
          title: 'Song',
          artist: 'Ann',
          durationMs: 61999,
        ),
        M3uExportEntry(path: '/m/b.mp3', title: 'Only title'),
        M3uExportEntry(path: '/m/gone.mp3'),
      ],
      style: M3uPathStyle.absolute,
      targetDir: '/lists',
    );

    expect(out.text, '''
#EXTM3U
#EXTINF:61,Ann - Song
/m/a.flac
#EXTINF:-1,Only title
/m/b.mp3
/m/gone.mp3
''');
    expect(out.written, 3);
    expect(out.skipped, 0);
  });

  test('relative lines are computed from the target folder', () {
    final out = writeM3u(
      const [
        M3uExportEntry(path: '/m/a.flac'),
        M3uExportEntry(path: '/lists/sub/b.flac'),
      ],
      style: M3uPathStyle.relative,
      targetDir: '/lists',
    );
    expect(out.text, '#EXTM3U\n../m/a.flac\nsub/b.flac\n');
  });

  test('guards relative lines read as comments or schemes', () {
    final out = writeM3u(
      const [
        M3uExportEntry(path: '/lists/#x.mp3'),
        M3uExportEntry(path: '/lists/Live:2019/a.flac'),
        M3uExportEntry(path: '/lists/a:b.mp3'),
        M3uExportEntry(path: '/Live:2019/a.flac'),
      ],
      style: M3uPathStyle.relative,
      targetDir: '/lists',
    );
    expect(
      out.text,
      '#EXTM3U\n./#x.mp3\n./Live:2019/a.flac\n./a:b.mp3\n../Live:2019/a.flac\n',
    );
  });

  test('leaves out paths that cannot be one line and counts them', () {
    final out = writeM3u(
      const [
        M3uExportEntry(path: '/m/a\nb.mp3', title: 'x'),
        M3uExportEntry(path: '/m/c\r.mp3'),
        M3uExportEntry(path: '/m/d\u0000.mp3'),
        M3uExportEntry(path: '/m/ok.mp3'),
      ],
      style: M3uPathStyle.absolute,
      targetDir: '/m',
    );
    expect(out.text, '#EXTM3U\n/m/ok.mp3\n');
    expect(out.written, 1);
    expect(out.skipped, 3);
  });

  test('control characters in titles become spaces', () {
    final out = writeM3u(
      const [M3uExportEntry(path: '/m/a.mp3', title: 'A\nB', artist: 'C\tD')],
      style: M3uPathStyle.absolute,
      targetDir: '/m',
    );
    expect(out.text, '#EXTM3U\n#EXTINF:-1,C D - A B\n/m/a.mp3\n');
  });
}
