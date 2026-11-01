import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/shared/show_in_file_manager.dart';
import 'package:kanaru/shared/track_menu_actions.dart';

import '../features/library/browse_test_data.dart';
import '../features/library/library_test_harness.dart';

void main() {
  /// A runner for a tile on /albums whose file manager answers with [show].
  Future<TrackMenuRunner> runner(
    WidgetTester tester,
    Future<bool> Function(String path) show,
  ) async {
    final h = LibraryHarness(
      overrides: [showInFileManagerProvider.overrideWithValue(show)],
    );
    await openWithTracks(tester, h, const [
      TestTrack('a1', artist: 'Ann', album: 'Alpha'),
    ], location: '/albums');
    final ref = tester.element(find.byType(KanaruApp)) as WidgetRef;
    return TrackMenuRunner(ref, tester.element(find.text('Alpha').first));
  }

  testWidgets('a file manager that cannot open the path says so', (
    tester,
  ) async {
    String? shown;
    final r = await runner(tester, (path) async {
      shown = path;
      return false;
    });

    await r.showInFileManagerAt('/music/a1.flac');
    await tester.pump();

    expect(shown, '/music/a1.flac');
    expect(find.text("Couldn't open the file manager"), findsOneWidget);
  });

  testWidgets('a file manager that throws says so too', (tester) async {
    final r = await runner(tester, (_) async => throw StateError('boom'));

    await r.showInFileManagerAt('/music/a1.flac');
    await tester.pump();

    expect(find.text("Couldn't open the file manager"), findsOneWidget);
  });
}
