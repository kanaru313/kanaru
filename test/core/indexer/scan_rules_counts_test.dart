import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/scan_rules.dart';
import 'package:kanaru/core/indexer/walk_audio_files.dart';

WalkedFile file(String path, {int size = 1000}) =>
    WalkedFile(path: path, mtimeMs: 1, sizeBytes: size);

void main() {
  const root = '/m';
  final walk = WalkResult(
    files: [
      file('/m/a.mp3'),
      file('/m/quiet/b.mp3'),
      file('/m/quiet/deep/c.mp3'),
      file('/m/skip/d.mp3'),
      file('/m/tiny.mp3', size: 10),
      // Inside a blocked folder and tiny: counts for the folder.
      file('/m/quiet/tiny.mp3', size: 10),
    ],
    dirs: ['/m', '/m/quiet', '/m/quiet/deep', '/m/skip'],
    nomediaDirs: ['/m/quiet'],
  );
  const rules = WalkRules(
    respectNomedia: true,
    minFileSizeBytes: 100,
    excludedPaths: ['/m/skip'],
  );

  test('files dropped are counted by reason, apart from filteredOut', () {
    final result = applyWalkRules(walk, root, rules);

    expect(result.nomediaOut, 3, reason: 'b, c and the tiny one in quiet');
    expect(result.excludedOut, 1);
    expect(result.tooSmallOut, 1);
    // 5 files, plus the 2 blocked folders the walk listed.
    expect(result.filteredOut, 5 + 2);
    expect(result.files.map((f) => f.path), ['/m/a.mp3']);
  });

  test('a rule that is off counts nothing', () {
    final result = applyWalkRules(
      walk,
      root,
      const WalkRules(minFileSizeBytes: 100),
    );

    expect(result.nomediaOut, 0);
    expect(result.excludedOut, 0);
    expect(result.tooSmallOut, 1 + 1);
  });

  test('the nearest blocked folder takes the file', () {
    final nested = WalkResult(
      files: [file('/m/ex/quiet/a.mp3'), file('/m/ex/b.mp3')],
      dirs: ['/m', '/m/ex', '/m/ex/quiet'],
      nomediaDirs: ['/m/ex/quiet'],
    );

    final result = applyWalkRules(
      nested,
      root,
      const WalkRules(respectNomedia: true, excludedPaths: ['/m/ex']),
    );

    expect(result.nomediaOut, 1);
    expect(result.excludedOut, 1);
  });

  test('a deferred file is not counted as left out', () {
    final result = applyWalkRules(
      WalkResult(files: [file('/m/a.mp3')]),
      root,
      const WalkRules(minFileSizeBytes: 100),
      settledBeforeMs: 0,
    );

    expect(result.tooSmallOut, 0);
    expect(result.deferred, 1);
  });
}
