import 'package:flutter_test/flutter_test.dart';

import '../../library/browse_test_data.dart';
import '../../library/library_test_harness.dart';
import '../add_to_playlist_test_support.dart';
import '../playlist_test_data.dart';
import 'playlist_modal_test_support.dart';

void main() {
  late LibraryHarness h;
  setUp(() => h = LibraryHarness());

  Future<(int, int)> open(
    WidgetTester tester, {
    List<String> missing = const [],
  }) async {
    await insertTracks(tester, h, const [TestTrack('a'), TestTrack('b')]);
    final source = await seedPlaylist(tester, h, 'Mix', [
      'a',
      'b',
      'a',
    ], extraPaths: missing);
    final target = await seedPlaylist(tester, h, 'Target', [], now: 2);
    await pumpModalHost(tester, h, id: source);
    await openPlaylistModalOf(tester);
    return (source, target);
  }

  testWidgets('the picker leaves out the playlist the songs come from', (
    tester,
  ) async {
    await open(tester);
    await tapModalAction(tester, 'add-to-playlist');

    expect(picker, findsOneWidget);
    expect(inPicker('Target'), findsOneWidget);
    expect(inPicker('Mix'), findsNothing);
  });

  testWidgets('copying [a, b, a] into an empty playlist gives [a, b, a]', (
    tester,
  ) async {
    final (source, target) = await open(tester);
    await tapModalAction(tester, 'add-to-playlist');
    await tester.tap(inPicker('Target'));
    await tester.pumpAndSettle();
    await tester.tap(pickerAdd);
    await settleDb(tester);

    final copied = await storedPaths(tester, h, target);
    expect(copied, await storedPaths(tester, h, source));
    expect(copied, hasLength(3));
    expect(copied[0], copied[2]);
  });

  testWidgets('entries whose file is missing are copied as stored', (
    tester,
  ) async {
    final (_, target) = await open(tester, missing: ['/gone/x.flac']);
    await tapModalAction(tester, 'add-to-playlist');
    await tester.tap(inPicker('Target'));
    await tester.pumpAndSettle();
    await tester.tap(pickerAdd);
    await settleDb(tester);

    expect(await storedPaths(tester, h, target), hasLength(4));
  });
}
