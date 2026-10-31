import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/lyrics/track_lyrics_preview_provider.dart';
import 'package:material_ui/material_ui.dart';

import 'package:kanaru/shared/song_modal/lyrics/lyrics_skeleton.dart';

import '../song_modal_test_support.dart';
import 'lyrics_modal_test_support.dart';

AsyncValue<TrackLyricsPreview?> _found(
  List<String> texts, {
  bool synced = false,
  String? online,
}) => AsyncData(
  TrackLyricsPreview(
    lyrics: lyricsOf(texts, synced: synced),
    onlineProviderId: online,
  ),
);

List<String> _numbered(int n) => [for (var i = 1; i <= n; i++) 'line $i'];

void main() {
  testWidgets('short lyrics show whole with no way to open more', (
    tester,
  ) async {
    await openLyricsInfo(tester, _found(_numbered(3)));

    expect(find.text('Lyrics'), findsOne);
    expect(find.text('.lrc file'), findsOne);
    expect(find.text('Synced'), findsNothing);
    expect(find.text('line 3'), findsOne);
    expect(find.byKey(const ValueKey('song-lyrics-view-all')), findsNothing);
  });

  testWidgets('long lyrics show 8 lines, the source and a count', (
    tester,
  ) async {
    final texts = _numbered(10)..[3] = '';
    await openLyricsInfo(tester, _found(texts, synced: true, online: 'lrclib'));

    expect(find.text('Online · LRCLIB'), findsOne);
    expect(find.text('Synced'), findsOne);
    expect(find.text('line 8'), findsOne);
    expect(find.text('line 9'), findsNothing);
    // Times are never part of the preview.
    expect(find.textContaining('00:'), findsNothing);
    expect(find.text('View all · 9 lines'), findsOne);
  });

  testWidgets('the count says 1 line for a single line of words', (
    tester,
  ) async {
    await openLyricsInfo(tester, _found(['', '', '', '', '', '', 'only']));
    expect(find.text('View all · 1 line'), findsOne);
  });

  testWidgets('loading shows still bars under reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await openLyricsInfo(tester, const AsyncLoading());

    final bars = find.descendant(
      of: find.byKey(const ValueKey('song-lyrics-skeleton')),
      matching: find.byType(FractionallySizedBox),
    );
    expect(bars, findsNWidgets(6));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the bars pulse when motion is allowed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LyricsSkeleton())),
    );
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('no lyrics show a card only while unknown fields show', (
    tester,
  ) async {
    final container = await openLyricsInfo(tester, const AsyncData(null));
    expect(find.text('No lyrics'), findsNothing);
    expect(find.text('Lyrics'), findsNothing);

    setShowUnknown(container, on: true);
    await tester.pump();
    expect(find.text('No lyrics'), findsOne);
    // Without a library there is nothing to search for.
    expect(find.byKey(const ValueKey('song-lyrics-find')), findsNothing);
  });

  testWidgets('Find online closes the modal and starts the search', (
    tester,
  ) async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await openLyricsInfo(
      tester,
      const AsyncData(null),
      overrides: [libraryDatabaseProvider.overrideWithValue(db)],
    );
    setShowUnknown(container, on: true);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('song-lyrics-find')));
    await settleSongModal(tester);

    expect(find.text('Song info'), findsNothing);
    // The notice that asks before anything is sent.
    expect(find.byType(AlertDialog), findsOne);
  });

  testWidgets('the card sits between the Tags and Audio groups', (
    tester,
  ) async {
    await openLyricsInfo(tester, _found(_numbered(2)));
    double top(Finder f) => tester.getTopLeft(f).dy;

    final card = top(find.byKey(const ValueKey('song-lyrics-card')));
    expect(top(find.text('TAGS')), lessThan(card));
    expect(card, lessThan(top(find.text('AUDIO'))));
  });
}
