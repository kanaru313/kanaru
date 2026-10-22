import 'package:drift/drift.dart' show QueryInterceptor, Value;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/features/history/history_clock.dart';
import 'package:kanaru/features/history/history_play_tile.dart';
import 'package:kanaru/features/history/history_timeline_view.dart';
import 'package:material_ui/material_ui.dart';

import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';

export '../library/browse_test_data.dart'
    show TestTrack, goTo, insertTracks, location;
export '../library/library_test_harness.dart' show LibraryHarness;

/// "Now" in the History widget tests: noon on 2026-10-23.
final historyTestNow = DateTime(2026, 10, 23, 12);

/// A harness whose History clock stands at [historyTestNow].
LibraryHarness historyHarness({
  List<Override> overrides = const [],
  QueryInterceptor? interceptor,
}) => LibraryHarness(
  overrides: [
    historyNowProvider.overrideWithValue(() => historyTestNow),
    ...overrides,
  ],
  interceptor: interceptor,
);

/// A library song at `/m/<name>.flac` titled [name].
TestTrack song(String name) => TestTrack(name, path: '/m/$name.flac');

/// A play of `/m/<name>.flac` started at [at].
typedef SeedPlay = (String name, DateTime at);

/// Stores [plays], straight into `plays` (so also for songs the library does
/// not have), and returns their ids in order.
Future<List<int>> seedPlays(
  WidgetTester tester,
  LibraryHarness h,
  List<SeedPlay> plays,
) async {
  final ids = await tester.runAsync(() async {
    return [
      for (final (name, at) in plays)
        await h.db
            .into(h.db.plays)
            .insert(
              PlaysCompanion.insert(
                path: '/m/$name.flac',
                playedAt: at.millisecondsSinceEpoch,
                listenedMs: const Value(60000),
              ),
            ),
    ];
  });
  return ids!;
}

/// Lets the work a change to `plays` sets off finish: the database event,
/// the page's debounce, the reads, and the frames after them.
Future<void> settleHistory(WidgetTester tester) async {
  Future<void> real() => tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 40)),
  );
  await real();
  await tester.pump(const Duration(milliseconds: 300));
  await real();
  await tester.pump();
  await real();
  await tester.pumpAndSettle();
}

/// Opens the app on the History page with [tracks] in the library and
/// [plays] played.
Future<void> openHistory(
  WidgetTester tester,
  LibraryHarness h, {
  List<TestTrack> tracks = const [],
  List<SeedPlay> plays = const [],
}) async {
  await insertTracks(tester, h, tracks);
  await seedPlays(tester, h, plays);
  await h.pump(tester, hasRoots: true);
  goTo(tester, h, '/history');
  await settleHistory(tester);
}

/// The list of the timeline, for its scroll position.
ScrollableState timelineScrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(HistoryTimelineView),
            matching: find.byType(Scrollable),
          )
          .last,
    );

double timelineOffset(WidgetTester tester) =>
    timelineScrollable(tester).position.pixels;

/// Moves the timeline to [offset] and draws it.
Future<void> scrollTimelineTo(WidgetTester tester, double offset) async {
  timelineScrollable(tester).position.jumpTo(offset);
  await settleHistory(tester);
}

/// Pixels of one line of the timeline.
const rowExtent = historyRowExtent;

/// [finder] among the lines of the list, not the sticky header drawn over it.
Finder inList(Finder finder) =>
    find.descendant(of: find.byType(ListView), matching: finder);

/// Text [text] among the lines of the list.
Finder listText(String text) => inList(find.text(text));

/// Text [text] in the sticky header.
Finder stickyText(String text) => find.descendant(
  of: find.byKey(historyStickyHeaderKey),
  matching: find.text(text),
);
