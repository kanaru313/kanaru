import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/folders/show_hidden_provider.dart';
import 'package:kanaru/shared/library_route_keys.dart';

import '../browse_test_data.dart';
import '../library_test_harness.dart';

/// Opens [location] with a real music folder, made on the disk and stored
/// as a root, holding the library songs named by [songs] (paths below it).
Future<String> openMusic(
  WidgetTester tester,
  LibraryHarness h, {
  List<String> songs = const ['a.flac'],
  String Function(String root)? location,
  void Function(String root)? prepare,
}) async {
  final root = h.folder('music');
  prepare?.call(root);
  await tester.runAsync(() => h.db.addRoots([root], now: 1));
  await insertTracks(tester, h, [
    for (final s in songs)
      TestTrack(
        s.split('/').last.replaceFirst(RegExp(r'\.\w+$'), ''),
        path: '$root/$s',
      ),
  ]);
  await h.pump(tester, hasRoots: true);
  goTo(tester, h, location == null ? folderLocation(root) : location(root));
  await settleIo(tester, h);
  return root;
}

/// Pumps with short real waits (the disk and the database answer in real
/// time) until [done] holds; the caller's expectations then report a miss.
Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Future<void> toggleEye(
  WidgetTester tester,
  LibraryHarness h, {
  Finder? until,
}) async {
  h.container.read(showHiddenFoldersProvider.notifier).toggle();
  await tester.pump();
  if (until != null) {
    await pumpUntil(tester, () => until.evaluate().isNotEmpty);
  }
  await settleIo(tester, h);
}

/// Opens the folder at [path] and waits for [until] to show.
Future<void> openPage(
  WidgetTester tester,
  LibraryHarness h,
  String path,
  Finder until,
) async {
  goTo(tester, h, folderLocation(path));
  await pumpUntil(tester, () => until.evaluate().isNotEmpty);
  await settleIo(tester, h);
}
