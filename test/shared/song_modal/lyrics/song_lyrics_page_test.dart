import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/track_lyrics_preview_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../song_modal_test_support.dart';
import 'lyrics_modal_test_support.dart';

AsyncValue<TrackLyricsPreview?> _found(
  List<String> texts, {
  bool synced = false,
}) => AsyncData(TrackLyricsPreview(lyrics: lyricsOf(texts, synced: synced)));

List<String> _numbered(int n) => [for (var i = 1; i <= n; i++) 'line $i'];

Future<void> _viewAll(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('song-lyrics-view-all')));
  await settleSongModal(tester);
}

void main() {
  testWidgets('View all opens every line under the song title', (tester) async {
    await openLyricsInfo(tester, _found(_numbered(12)));
    await _viewAll(tester);

    expect(find.text('Lyrics · one'), findsOne);
    expect(find.text('line 12'), findsOne);
    expect(find.byKey(const ValueKey('song-lyrics-times')), findsNothing);
    expect(find.byKey(const ValueKey('song-lyrics-copy')), findsOne);
  });

  testWidgets('plain lyrics have no timestamp toggle, synced ones do', (
    tester,
  ) async {
    await openLyricsInfo(tester, _found(_numbered(8), synced: true));
    await _viewAll(tester);

    expect(find.text('00:03'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('song-lyrics-times')));
    await tester.pump();
    expect(find.text('00:03'), findsOne);
    expect(find.byTooltip('Hide timestamps'), findsOne);

    await tester.tap(find.byKey(const ValueKey('song-lyrics-times')));
    await tester.pump();
    expect(find.text('00:03'), findsNothing);
  });

  testWidgets('copy puts the plain text on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final texts = _numbered(8)..[1] = '';
    await openLyricsInfo(tester, _found(texts, synced: true));
    await _viewAll(tester);
    // Even with times shown, the copy has none.
    await tester.tap(find.byKey(const ValueKey('song-lyrics-times')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('song-lyrics-copy')));
    await tester.pump();

    expect(copied, texts.join('\n'));
    expect(find.text('Lyrics copied'), findsOne);
  });

  testWidgets('ten thousand lines build only the visible rows', (tester) async {
    await openLyricsInfo(tester, _found(_numbered(10000)));
    await _viewAll(tester);

    expect(find.text('line 1'), findsOne);
    final built = find.textContaining('line ');
    expect(built.evaluate().length, lessThan(60));
  });

  testWidgets('Back returns to the same place on the Song info page', (
    tester,
  ) async {
    await openLyricsInfo(tester, _found(_numbered(12)));
    // A short window, so the info page has to scroll.
    tester.view.physicalSize = const Size(360, 420);
    await tester.pumpAndSettle();
    final list = find.byType(ListView).first;
    final viewAll = find.byKey(const ValueKey('song-lyrics-view-all'));
    await tester.ensureVisible(viewAll);
    await tester.pumpAndSettle();
    final before = tester.widget<ListView>(list).controller!.offset;
    expect(before, greaterThan(0));

    await tester.tap(viewAll);
    await settleSongModal(tester);
    expect(find.text('Lyrics · one'), findsOne);
    await tester.tap(find.byTooltip('Back'));
    await settleSongModal(tester);

    expect(find.text('Song info'), findsWidgets);
    expect(tester.widget<ListView>(list).controller!.offset, before);
  });
}
