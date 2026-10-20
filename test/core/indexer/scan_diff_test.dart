import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/core/indexer/scan_diff.dart';
import 'package:kanaru/core/indexer/walk_audio_files.dart';

WalkedFile file(String path, {int mtime = 1, int size = 10}) =>
    WalkedFile(path: path, mtimeMs: mtime, sizeBytes: size);

TrackSnapshot row(
  int id,
  String path, {
  int mtime = 1,
  int size = 10,
  bool error = false,
  int coverVersion = 0,
}) => TrackSnapshot(
  id: id,
  path: path,
  mtimeMs: mtime,
  sizeBytes: size,
  hasScanError: error,
  coverScanVersion: coverVersion,
);

void main() {
  test('new file is read and counted as added', () {
    final diff = diffScan(WalkResult(files: [file('/m/a.mp3')]), []);
    expect(diff.toRead.map((f) => f.path), ['/m/a.mp3']);
    expect(diff.added, 1);
    expect(diff.updated, 0);
  });

  test('changed mtime or size is read again as updated', () {
    final diff = diffScan(
      WalkResult(
        files: [file('/m/a.mp3', mtime: 2), file('/m/b.mp3', size: 11)],
      ),
      [row(1, '/m/a.mp3'), row(2, '/m/b.mp3')],
    );
    expect(diff.toRead, hasLength(2));
    expect(diff.added, 0);
    expect(diff.updated, 2);
    expect(diff.toDelete, isEmpty);
  });

  test('unchanged file is skipped', () {
    final diff = diffScan(WalkResult(files: [file('/m/a.mp3')]), [
      row(1, '/m/a.mp3'),
    ]);
    expect(diff.toRead, isEmpty);
    expect(diff.toDelete, isEmpty);
  });

  test('a vanished file is deleted', () {
    final diff = diffScan(WalkResult(files: [file('/m/a.mp3')]), [
      row(1, '/m/a.mp3'),
      row(2, '/m/gone.mp3'),
    ]);
    expect(diff.toDelete, [2]);
  });

  test(
    'tracks under an unreadable folder are kept, siblings by prefix not',
    () {
      final diff = diffScan(
        WalkResult(files: [file('/m/a.mp3')], unreadableDirs: ['/m/locked']),
        [
          row(1, '/m/a.mp3'),
          row(2, '/m/locked/deep/x.mp3'),
          row(3, '/m/locked2/y.mp3'),
        ],
      );
      expect(diff.toDelete, [3]);
    },
  );

  test('unstattable files are kept', () {
    final diff = diffScan(
      WalkResult(files: [file('/m/a.mp3')], unstattable: ['/m/b.mp3']),
      [row(1, '/m/a.mp3'), row(2, '/m/b.mp3')],
    );
    expect(diff.toDelete, isEmpty);
  });

  test('missing root deletes and reads nothing', () {
    final diff = diffScan(const WalkResult(rootMissing: true), [
      row(1, '/m/a.mp3'),
    ]);
    expect(diff.toDelete, isEmpty);
    expect(diff.toRead, isEmpty);
    expect(diff.rootEmpty, isFalse);
  });

  test('empty walk with stored tracks is rootEmpty and deletes nothing', () {
    final diff = diffScan(const WalkResult(), [row(1, '/m/a.mp3')]);
    expect(diff.rootEmpty, isTrue);
    expect(diff.toDelete, isEmpty);
  });

  test('empty walk and empty database is fine', () {
    final diff = diffScan(const WalkResult(), []);
    expect(diff.rootEmpty, isFalse);
    expect(diff.toRead, isEmpty);
    expect(diff.toDelete, isEmpty);
  });

  test('an empty folder keeps what was stored below it', () {
    final diff = diffScan(
      WalkResult(files: [file('/m/a.mp3')], emptyDirs: ['/m/nas']),
      [
        row(1, '/m/a.mp3'),
        row(2, '/m/nas/deep/x.mp3'),
        row(3, '/m/nas2/y.mp3'),
      ],
    );
    expect(diff.toDelete, [3]);
  });

  test('an unchanged file with a scan error is read again, not "updated"', () {
    final diff = diffScan(
      WalkResult(files: [file('/m/a.mp3'), file('/m/b.mp3')]),
      [row(1, '/m/a.mp3', error: true), row(2, '/m/b.mp3')],
    );
    expect(diff.toRead.map((f) => f.path), ['/m/a.mp3']);
    expect(diff.added, 0);
    expect(diff.updated, 0);
  });

  group('cover rules', () {
    final walk = WalkResult(files: [file('/m/a.mp3'), file('/m/b.mp3')]);
    final existing = [
      row(1, '/m/a.mp3'),
      row(2, '/m/b.mp3', coverVersion: coverScanVersion),
    ];

    test('an unchanged file looked at under older rules is read again', () {
      final diff = diffScan(walk, existing, coversEnabled: true);
      expect(diff.toRead.map((f) => f.path), ['/m/a.mp3']);
      expect(diff.added, 0);
      expect(diff.updated, 0);
    });

    test('with covers off the rules version is ignored', () {
      expect(diffScan(walk, existing).toRead, isEmpty);
    });
  });
}
