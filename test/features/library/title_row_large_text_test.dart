import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _tracks = [
  TestTrack('one', artist: 'Zed', album: 'Beta', year: 1999),
  TestTrack('two', artist: 'Amy', album: 'Alpha', year: 2005),
];

void main() {
  for (final (location, title) in [
    ('/songs', 'Songs'),
    ('/albums', 'Albums'),
    ('/artists', 'Artists'),
  ]) {
    testWidgets('the $location title row fits the smallest window with '
        'large text', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: location);
      tester.view.physicalSize = const Size(480, 720);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();

      // An overflow would fail the test with a layout error.
      expect(tester.takeException(), isNull);
      expect(find.text(title).last, findsOneWidget);
      // The actions stay inside the window.
      final actions = find.descendant(
        of: find.byType(FittedBox),
        matching: find.byWidgetPredicate(
          (w) => w is TextButton || w is IconButton,
        ),
      );
      expect(actions, findsWidgets);
      for (final action in actions.evaluate()) {
        final rect = tester.getRect(find.byWidget(action.widget));
        expect(rect.right, lessThanOrEqualTo(480), reason: location);
        expect(rect.left, greaterThanOrEqualTo(0), reason: location);
      }
    });
  }
}
