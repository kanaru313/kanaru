import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/native/file_trash.dart';

void main() {
  group('trashWithGio', () {
    test('a missing path is notFound and touches nothing', () {
      final dir = Directory.systemTemp.createTempSync('kanaru_trash_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final before = dir.listSync();

      // Runs GLib's error branch: the domain, the code and g_error_free.
      final result = trashWithGio('${dir.path}/does-not-exist.lrc');

      expect(result, TrashResult.notFound);
      expect(dir.listSync(), before);
    });

    test('repeated error calls keep working (the error is freed)', () {
      for (var i = 0; i < 200; i++) {
        expect(
          trashWithGio('/nonexistent-kanaru-dir/$i'),
          TrashResult.notFound,
        );
      }
    });

    test('no library to load is unsupported', () {
      expect(
        trashWithGio('/tmp/x', loaders: [() => throw ArgumentError('none')]),
        TrashResult.unsupported,
      );
      expect(trashWithGio('/tmp/x', loaders: []), TrashResult.unsupported);
    });
  });

  group('GioFileTrash', () {
    test('passes the answer through', () async {
      final trash = GioFileTrash(run: (_) async => TrashResult.trashed);

      expect(await trash.trash('/x'), TrashResult.trashed);
    });

    test('a call that takes too long is timedOut', () async {
      final never = Completer<TrashResult>();
      final trash = GioFileTrash(
        timeout: const Duration(milliseconds: 20),
        run: (_) => never.future,
      );

      expect(await trash.trash('/x'), TrashResult.timedOut);
    });

    test('an error from the isolate is failed, not thrown', () async {
      final trash = GioFileTrash(run: (_) async => throw StateError('boom'));

      expect(await trash.trash('/x'), TrashResult.failed);
    });

    test('the real isolate path answers notFound for a missing file', () async {
      expect(
        await GioFileTrash().trash('/nonexistent-kanaru-dir/a.lrc'),
        TrashResult.notFound,
      );
    });
  });
}
