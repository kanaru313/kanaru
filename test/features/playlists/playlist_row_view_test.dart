import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/playlists/playlist_entry_tile.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/favorite_button.dart';
import 'package:material_ui/material_ui.dart';

import 'playlist_entries_view_harness.dart';
import 'playlist_test_data.dart' show hoverRow;

/// What a playlist row shows and when its actions appear.
void main() {
  final view = EntriesViewHarness();
  setUp(view.reset);

  final remove = find.byTooltip('Remove from playlist');

  /// Opacity of the wrapper that hides the remove button of row [index].
  double removeOpacity(WidgetTester tester, int index) {
    final button = find.descendant(
      of: find.byType(PlaylistEntryTile).at(index),
      matching: remove,
    );
    return tester
        .widget<Opacity>(
          find.ancestor(of: button, matching: find.byType(Opacity)).first,
        )
        .opacity;
  }

  testWidgets('rows show no number and a handle each', (tester) async {
    await view.pump(tester, [available(1), available(2), missing(3)]);

    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
    expect(find.byIcon(AppIcons.dragHandle), findsNWidgets(3));
  });

  testWidgets('a missing row shows its file name and is dimmed', (
    tester,
  ) async {
    await view.pump(tester, [missing(1)]);

    expect(find.text('lost1.mp3'), findsOneWidget);
    expect(find.text('Not in library'), findsOneWidget);
    final dim = tester.widget<Opacity>(
      find
          .descendant(
            of: find.byType(PlaylistEntryTile),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(dim.opacity, lessThan(1));
  });

  testWidgets('a missing row has no queue menu and does not play', (
    tester,
  ) async {
    await view.pump(tester, [missing(1)], onEntryQueueAction: (_, _) {});

    await tester.tap(find.text('lost1.mp3'));
    await tester.pump();

    expect(view.played, isEmpty);
  });

  group('remove button', () {
    testWidgets('is hidden at rest', (tester) async {
      await view.pump(tester, [available(1), available(2)]);

      expect(removeOpacity(tester, 0), 0);
      expect(removeOpacity(tester, 1), 0);
    });

    testWidgets('shows on the row the mouse is over only', (tester) async {
      await view.pump(tester, [available(1), available(2)]);

      await hoverRow(tester, 1);

      expect(removeOpacity(tester, 0), 0);
      expect(removeOpacity(tester, 1), 1);
    });

    testWidgets('shows for a missing row on hover', (tester) async {
      await view.pump(tester, [missing(1)]);
      expect(removeOpacity(tester, 0), 0);

      await hoverRow(tester, 0);
      await tester.tap(remove);

      expect(view.removed, [1]);
    });

    testWidgets('shows when keyboard focus reaches it', (tester) async {
      await view.pump(tester, [available(1), available(2)]);

      // Tab walks the focusable parts; the first row's controls come first.
      for (var i = 0; i < 6 && removeOpacity(tester, 0) == 0; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }

      expect(removeOpacity(tester, 0), 1);
      expect(removeOpacity(tester, 1), 0);
    });

    testWidgets('a hidden button does not take the tap', (tester) async {
      await view.pump(tester, [available(1)]);

      await tester.tap(remove, warnIfMissed: false);
      await tester.pump();

      expect(view.removed, isEmpty);
    });
  });

  testWidgets('clicking the handle does not play', (tester) async {
    await view.pump(tester, [available(1), available(2)]);

    await tester.tap(find.byIcon(AppIcons.dragHandle).first);
    await tester.pump(const Duration(milliseconds: 400));

    expect(view.played, isEmpty);
  });

  testWidgets('clicking the row plays from it', (tester) async {
    await view.pump(tester, [available(1), available(2)]);

    await tester.tap(find.text('T2'));
    await tester.pump();

    expect(view.played, [(2, 1)]);
  });

  testWidgets('a row shows the heart and the song menu', (tester) async {
    await view.pump(tester, [available(1)], onEntryQueueAction: (_, _) {});

    expect(
      find.descendant(
        of: find.byType(PlaylistEntryTile),
        matching: find.byType(FavoriteButton),
      ),
      findsOneWidget,
    );
    await tester.longPress(find.text('T1'));
    await tester.pumpAndSettle();
    expect(find.text('Play next'), findsOneWidget);
  });
}
