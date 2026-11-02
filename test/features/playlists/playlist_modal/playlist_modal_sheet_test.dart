import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_dialog_frame.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_sheet_frame.dart';

import '../../library/browse_test_data.dart';
import '../../library/library_test_harness.dart';
import '../playlist_test_data.dart';
import 'playlist_modal_test_support.dart';

void main() {
  late LibraryHarness h;
  setUp(() => h = LibraryHarness());

  Future<void> open(WidgetTester tester, Size size) async {
    await insertTracks(tester, h, const [TestTrack('a')]);
    final id = await seedPlaylist(tester, h, 'Mix', ['a']);
    await pumpModalHost(tester, h, id: id, size: size);
    await openPlaylistModalOf(tester);
  }

  testWidgets('a narrow window uses the sheet frame', (tester) async {
    await open(tester, const Size(420, 800));
    expect(find.byType(ContextModalSheetFrame), findsOneWidget);
    expect(find.byType(ContextModalDialogFrame), findsNothing);
    expect(modalAction('play-all'), findsOneWidget);
    expect(find.text('Playlist options'), findsNothing);
  });

  testWidgets('a wide window uses the dialog frame', (tester) async {
    await open(tester, const Size(1000, 800));
    expect(find.byType(ContextModalDialogFrame), findsOneWidget);
    expect(find.byType(ContextModalSheetFrame), findsNothing);
  });
}
