import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/queue/queue_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../library/library_test_harness.dart';
import '../playlists/playlist_test_data.dart';

/// Plays [queue] and opens the queue sheet.
Future<void> playAndOpenQueue(
  WidgetTester tester,
  LibraryHarness h,
  List<Track> queue,
) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await h.container.read(playerServiceProvider.notifier).openTracks(queue);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Show now playing list'));
  await tester.pumpAndSettle();
}

Finder queueRow(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(QueueTile));

/// Right clicks the row titled [title] and waits for the menu.
Future<void> openQueueMenu(WidgetTester tester, String title) async {
  await tester.tap(queueRow(title).last, buttons: kSecondaryButton);
  await settleDb(tester);
  await tester.pumpAndSettle();
}

/// Titles of the queue in play order.
List<String> queueTitles(LibraryHarness h) {
  final queue = h.container.read(playerServiceProvider).queue;
  return [for (final i in queue.order) queue.original[i].title];
}

/// Any menu row, whatever its value type.
final _menuItem = find.byWidgetPredicate((w) => w is PopupMenuItem);

/// The labels of the open menu, top to bottom.
List<String> menuLabels(WidgetTester tester, Iterable<String> candidates) {
  final found = <(double, String)>[
    for (final label in candidates)
      for (final item
          in find
              .descendant(of: _menuItem, matching: find.text(label))
              .evaluate())
        (tester.getTopLeft(find.byWidget(item.widget)).dy, label),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final f in found) f.$2];
}

const allMenuLabels = [
  'Play next',
  'Add to playlist…',
  'Add to favorites',
  'Remove from favorites',
  'Find lyrics online…',
  'Show artist',
  'Show album',
  'Show in folder',
  'Show in file manager',
  'Remove from queue',
];

/// Whether the menu row labelled [label] is enabled.
bool menuRowEnabled(WidgetTester tester, String label) => tester
    .widget<PopupMenuItem<dynamic>>(
      find.ancestor(of: find.text(label), matching: _menuItem),
    )
    .enabled;
