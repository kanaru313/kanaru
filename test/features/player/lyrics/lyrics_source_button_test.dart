import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/features/player/lyrics/source/lyrics_source_button.dart';

import 'lyrics_source_button_harness.dart';

/// The open modal's marquee text never stops animating, so no pumpAndSettle.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  final modalTitle = find.text('Lyrics for this song');
  final shown = fakeResolution(
    LyricsFound(modalUri, modalLyrics()),
    effective: LyricsChoice.local,
    hasLocal: true,
  );

  Future<void> rightClick(WidgetTester tester) async {
    await tester.tap(
      find.byType(LyricsSourceButton),
      buttons: kSecondaryButton,
    );
    await tester.pump();
  }

  testWidgets('a press opens the modal and reports it open, then closed', (
    tester,
  ) async {
    final h = await pumpLyricsButton(tester, shown);
    await tester.tap(find.byType(LyricsSourceButton));
    await settle(tester);
    expect(modalTitle, findsOneWidget);
    expect(h.events, [true]);

    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(modalTitle, findsNothing);
    expect(h.events, [true, false]);
  });

  testWidgets('the opener callback opens the modal once', (tester) async {
    final h = await pumpLyricsButton(tester, shown);
    final open = h.opener.value!;
    expect(open(), isTrue);
    await settle(tester);
    expect(modalTitle, findsOneWidget);
    expect(open(), isFalse);
  });

  testWidgets('the opener is cleared when nothing plays and when it leaves', (
    tester,
  ) async {
    final h = await pumpLyricsButton(tester, shown);
    expect(h.opener.value, isNotNull);
    h.resolution.emit(null);
    await tester.pump();
    await tester.pump();
    expect(h.opener.value, isNull);
    expect(find.byType(IconButton), findsNothing);

    h.resolution.emit(shown);
    await tester.pump();
    await tester.pump();
    expect(h.opener.value, isNotNull);
    await tester.pumpWidget(const SizedBox());
    expect(h.opener.value, isNull);
  });

  testWidgets('another song closes the open modal', (tester) async {
    final h = await pumpLyricsButton(tester, shown);
    await tester.tap(find.byType(LyricsSourceButton));
    await settle(tester);
    h.resolution.emit(
      fakeResolution(LyricsFound(otherTrack.uri, modalLyrics())),
    );
    await settle(tester);
    expect(modalTitle, findsNothing);
    expect(h.events.last, isFalse);
  });

  group('a right click', () {
    testWidgets('turns lyrics off', (tester) async {
      final h = await pumpLyricsButton(tester, shown);
      await rightClick(tester);
      expect(h.log, ['choose off']);
      expect(modalTitle, findsNothing);
    });

    testWidgets('turns them back on when they are off', (tester) async {
      final h = await pumpLyricsButton(
        tester,
        fakeResolution(
          LyricsNone(modalUri, LyricsNoneReason.off),
          chosen: LyricsChoice.off,
          effective: LyricsChoice.off,
          hasLocal: true,
        ),
      );
      await rightClick(tester);
      expect(h.log, ['turnOn']);
    });

    testWidgets('does nothing without the library', (tester) async {
      final h = await pumpLyricsButton(tester, shown, library: false);
      await rightClick(tester);
      expect(h.log, isEmpty);
    });
  });
}
