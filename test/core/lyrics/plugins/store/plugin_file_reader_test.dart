import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_reader.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_file_reader.dart';

import '../package/package_test_helpers.dart';
import 'store_test_env.dart';

void main() {
  late Directory tmp;
  setUp(
    () async => tmp = await Directory.systemTemp.createTemp('kanaru-file-'),
  );
  tearDown(() => tmp.delete(recursive: true));

  Future<PluginPackageProblemKind?> kindOf(String path, {int? max}) async {
    try {
      await readPluginFile(path, maxBytes: max ?? 5 * 1024 * 1024);
      return null;
    } on PluginPackageProblem catch (p) {
      return p.kind;
    }
  }

  test('reads a regular file', () async {
    final file = File('${tmp.path}/a.zip')..writeAsBytesSync([1, 2, 3]);
    expect(await readPluginFile(file.path), [1, 2, 3]);
  });

  test('a file over the cap is tooLarge, exactly the cap is fine', () async {
    final file = File('${tmp.path}/a.zip')
      ..writeAsBytesSync(List.filled(11, 0));
    expect(await kindOf(file.path, max: 10), PluginPackageProblemKind.tooLarge);
    expect(await kindOf(file.path, max: 11), isNull);
  });

  test('a folder, a missing path and a pipe are refused', () async {
    expect(await kindOf(tmp.path), PluginPackageProblemKind.notZip);
    expect(
      await kindOf('${tmp.path}/none.zip'),
      PluginPackageProblemKind.notZip,
    );
    final fifo = '${tmp.path}/pipe';
    final made = await Process.run('mkfifo', [fifo]);
    if (made.exitCode == 0) {
      expect(await kindOf(fifo), PluginPackageProblemKind.notZip);
    }
  });

  test('a symbolic link to a regular file is followed', () async {
    final file = File('${tmp.path}/a.zip')..writeAsBytesSync([7]);
    await Link('${tmp.path}/link.zip').create(file.path);
    expect(await readPluginFile('${tmp.path}/link.zip'), [7]);
  });

  test('a stuck syntax check makes the reader refuse the package', () async {
    final reader = PluginPackageReader(
      TimeLimitedCheckRuntime(
        FakeRuntime(hang: true),
        limit: const Duration(milliseconds: 50),
      ),
    );
    final result = await reader.read(validZip());
    expect(result, isA<PluginPackageRejected>());
    expect(
      (result as PluginPackageRejected).problem.kind,
      PluginPackageProblemKind.checkUnavailable,
    );
  });

  test(
    'a stalled read ends at the limit even if cancel never returns',
    () async {
      final stalled = StreamController<List<int>>(
        onCancel: () => Completer<void>().future, // a cancel that hangs
      );
      File('${tmp.path}/x.zip').writeAsBytesSync([1]);
      final watch = Stopwatch()..start();
      await expectLater(
        readPluginFile(
          '${tmp.path}/x.zip',
          limit: const Duration(milliseconds: 100),
          open: (_) => stalled.stream,
        ),
        throwsA(
          isA<PluginPackageProblem>()
              .having((p) => p.kind, 'kind', PluginPackageProblemKind.notZip)
              .having((p) => p.detail, 'detail', 'read timed out'),
        ),
      );
      expect(watch.elapsedMilliseconds, lessThan(2000));
    },
  );
}
