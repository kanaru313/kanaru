import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/features/player/lyrics/plain_lyrics_view.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('desktop shows no scrollbar, and a drag still scrolls', (
    tester,
  ) async {
    final lyrics = Lyrics(
      lines: [for (var i = 0; i < 60; i++) LyricLine(Duration.zero, 'row $i')],
      synced: false,
      source: LyricsSource.sidecar,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: Scaffold(body: PlainLyricsView(lyrics: lyrics)),
      ),
    );
    final scrollbar = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.foregroundPainter is ScrollbarPainter,
    );
    expect(scrollbar, findsNothing);

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0));
    expect(scrollbar, findsNothing);
  });

  testWidgets('the mouse wheel scrolls the list', (tester) async {
    final lyrics = Lyrics(
      lines: [for (var i = 0; i < 60; i++) LyricLine(Duration.zero, 'row $i')],
      synced: false,
      source: LyricsSource.sidecar,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: Scaffold(body: PlainLyricsView(lyrics: lyrics)),
      ),
    );
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;

    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(find.byType(ListView)),
        scrollDelta: const Offset(0, 200),
      ),
    );
    await tester.pump();

    expect(position.pixels, greaterThan(0));
  });
}
