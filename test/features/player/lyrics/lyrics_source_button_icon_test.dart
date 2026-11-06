import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/features/player/lyrics/source/lyrics_source_button.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/lyrics_plugins/plugin_icon.dart';
import 'package:material_ui/material_ui.dart';

import 'lyrics_source_button_harness.dart';

void main() {
  final alpha = [modalRecord('plugin-a', 'Alpha')];

  IconButton button(WidgetTester tester) => tester.widget(
    find.descendant(
      of: find.byType(LyricsSourceButton),
      matching: find.byType(IconButton),
    ),
  );

  Color? color(WidgetTester tester) =>
      button(tester).style?.foregroundColor?.resolve({});

  Finder icon(IconData data) => find.descendant(
    of: find.byType(LyricsSourceButton),
    matching: find.byIcon(data),
  );

  final ring = find.descendant(
    of: find.byType(LyricsSourceButton),
    matching: find.byType(CircularProgressIndicator),
  );

  testWidgets('the song\'s own lyrics: lyrics icon in the primary colour', (
    tester,
  ) async {
    await pumpLyricsButton(
      tester,
      fakeResolution(LyricsFound(modalUri, modalLyrics())),
    );
    expect(icon(AppIcons.lyrics), findsOneWidget);
    expect(
      color(tester),
      Theme.of(tester.element(find.byType(LyricsSourceButton)))
          .colorScheme
          .primary,
    );
    expect(ring, findsNothing);
  });

  testWidgets('online lyrics: the plugin icon on a raised background', (
    tester,
  ) async {
    await pumpLyricsButton(
      tester,
      fakeResolution(
        LyricsFound(modalUri, modalLyrics(), origin: modalOrigin()),
      ),
      records: alpha,
    );
    final plugin = tester.widget<PluginIcon>(find.byType(PluginIcon));
    expect(plugin.size, 20);
    expect(plugin.letterOf, 'Alpha');
    expect(plugin.record?.installId, 'plugin-a');
    expect(button(tester).style?.backgroundColor, isNotNull);
  });

  testWidgets('online lyrics of a removed plugin: its letter', (tester) async {
    await pumpLyricsButton(
      tester,
      fakeResolution(
        LyricsFound(
          modalUri,
          modalLyrics(),
          origin: modalOrigin(id: 'plugin-gone'),
        ),
      ),
      records: alpha,
    );
    final plugin = tester.widget<PluginIcon>(find.byType(PluginIcon));
    expect(plugin.record, isNull);
    expect(plugin.letterOf, isNotEmpty);
  });

  testWidgets('lyrics off: the struck-through icon', (tester) async {
    await pumpLyricsButton(
      tester,
      fakeResolution(
        LyricsNone(modalUri, LyricsNoneReason.off),
        chosen: LyricsChoice.off,
        effective: LyricsChoice.off,
      ),
    );
    expect(icon(AppIcons.lyricsOff), findsOneWidget);
  });

  for (final reason in [
    LyricsNoneReason.noLyrics,
    LyricsNoneReason.notFound,
    LyricsNoneReason.error,
  ]) {
    testWidgets('${reason.name}: a dim lyrics icon', (tester) async {
      await pumpLyricsButton(
        tester,
        fakeResolution(LyricsNone(modalUri, reason)),
      );
      expect(icon(AppIcons.lyrics), findsOneWidget);
      expect(color(tester)!.a, closeTo(0.6, 0.01));
    });
  }

  testWidgets('a lookup turns a ring around the icon, reading does not', (
    tester,
  ) async {
    final h = await pumpLyricsButton(
      tester,
      fakeResolution(LyricsReading(modalUri)),
    );
    expect(ring, findsNothing);
    h.resolution.emit(fakeResolution(LyricsSearching(modalUri, 'plugin-a')));
    await tester.pump();
    expect(ring, findsOneWidget);
    h.resolution.emit(fakeResolution(LyricsFound(modalUri, modalLyrics())));
    await tester.pump();
    expect(ring, findsNothing);
  });

  testWidgets('the tooltip names the lyrics and the clicks', (tester) async {
    await pumpLyricsButton(
      tester,
      fakeResolution(LyricsFound(modalUri, modalLyrics())),
    );
    expect(button(tester).tooltip, '''.lrc file
Click: lyrics options · Right-click: turn on/off · L''');
  });

  testWidgets('the tooltip is Vietnamese', (tester) async {
    await pumpLyricsButton(
      tester,
      fakeResolution(LyricsNone(modalUri, LyricsNoneReason.off)),
      locale: const Locale('vi'),
    );
    expect(button(tester).tooltip, contains('Bấm: tuỳ chọn lời'));
  });

  testWidgets('nothing plays: no button', (tester) async {
    await pumpLyricsButton(tester, null);
    expect(find.byType(IconButton), findsNothing);
  });
}
