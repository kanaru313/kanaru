import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lets the modal's database reads (links, favorite) finish and its
/// animations end. A plain `pumpAndSettle` cannot wait for real I/O.
Future<void> settleSongModal(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await tester.pumpAndSettle();
  // Streams disposed with a page leave a zero-delay timer of the database.
  await tester.pump(const Duration(milliseconds: 100));
}

/// Opens the song modal of the row [finder] with a right click and waits for
/// its links and favorite to load.
Future<void> openSongModal(WidgetTester tester, Finder finder) async {
  await tester.tap(finder, buttons: kSecondaryButton);
  await settleSongModal(tester);
}

/// Taps the row of the open modal labelled [label] and waits for what it
/// starts.
Future<void> tapModalAction(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await settleSongModal(tester);
}

/// The row of the open modal with action [id].
Finder modalAction(String id) =>
    find.byKey(ValueKey('context-modal-action-$id'));
