import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:material_ui/material_ui.dart';

import 'lyrics_source_modal_test_harness.dart';

/// The modal's marquee text never stops animating, so no pumpAndSettle.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  final two = [
    modalRecord('plugin-a', 'Alpha'),
    modalRecord('plugin-b', 'Beta'),
  ];
  LyricsNone none(LyricsNoneReason r) => LyricsNone(modalUri, r);

  Future<SourceModalHarness> pump(
    WidgetTester tester,
    PlayingLyricsStatus status, {
    List<dynamic>? records,
    Set<String> disabled = const {},
    bool auto = true,
  }) => pumpSourceModal(
    tester,
    fakeResolution(status),
    records: [...(records ?? two)].cast(),
    disabled: disabled,
    autoAllowed: auto,
  );

  testWidgets('searching counts the enabled sources', (tester) async {
    await pump(tester, LyricsSearching(modalUri, 'plugin-a'));
    expect(
      find.text('No lyrics on this device · searching 2 sources…'),
      findsOneWidget,
    );
  });

  testWidgets('no plugin installed: no button', (tester) async {
    await pump(tester, none(LyricsNoneReason.noLyrics), records: []);
    expect(
      find.text('No lyrics on this device · no online source yet'),
      findsOneWidget,
    );
    expect(find.text('Turn on automatic search'), findsNothing);
  });

  testWidgets('every source off', (tester) async {
    await pump(
      tester,
      none(LyricsNoneReason.noLyrics),
      disabled: {'plugin-a', 'plugin-b'},
    );
    expect(
      find.text('No lyrics on this device · every online source is off'),
      findsOneWidget,
    );
  });

  testWidgets('automatic search off: button asks for consent', (tester) async {
    await pump(tester, none(LyricsNoneReason.noLyrics), auto: false);
    expect(
      find.text('No lyrics on this device · automatic search is off'),
      findsOneWidget,
    );
    await tester.tap(find.text('Turn on automatic search'));
    await settle(tester);
    expect(find.text('Lyrics for this song'), findsOneWidget);
    expect(find.text('Find lyrics online automatically?'), findsOneWidget);
  });

  testWidgets('Turn on keeps the modal open and notes a song without tags', (
    tester,
  ) async {
    final h = await pumpSourceModal(
      tester,
      fakeResolution(none(LyricsNoneReason.noLyrics)),
      records: two,
      autoAllowed: false,
      autoSearchable: false,
    );
    await tester.tap(find.text('Turn on automatic search'));
    await settle(tester);
    await tester.tap(find.text('Turn on'));
    await settle(tester);
    expect(find.text('Lyrics for this song'), findsOneWidget);
    expect(find.textContaining('lacks a title, artist or length'), findsOne);
    expect(find.byType(SnackBar), findsNothing);
    expect(h.location, '/');
  });

  testWidgets('the notice settings link opens the playback lyrics settings', (
    tester,
  ) async {
    final h = await pumpSourceModal(
      tester,
      fakeResolution(none(LyricsNoneReason.noLyrics)),
      records: two,
      autoAllowed: false,
    );
    await tester.tap(find.text('Turn on automatic search'));
    await settle(tester);
    await tester.tap(find.text('Open lyrics settings'));
    await settle(tester);
    expect(h.location, settingsFocusLocation(SettingsAnchor.playbackLyrics));
    expect(find.text('Lyrics for this song'), findsNothing);
  });

  testWidgets('searching with no counted source has no count', (tester) async {
    await pump(tester, LyricsSearching(modalUri, 'plugin-a'), records: []);
    expect(find.text('Searching…'), findsOneWidget);
  });

  testWidgets('paused uses the neutral line', (tester) async {
    await pump(tester, none(LyricsNoneReason.paused));
    expect(find.text('Lookups paused'), findsOneWidget);
    expect(find.textContaining('plugin-'), findsNothing);
  });

  testWidgets('not found, error with retry, instrumental', (tester) async {
    await pump(tester, none(LyricsNoneReason.notFound));
    expect(
      find.text('No lyrics found, even in 2 enabled sources'),
      findsOneWidget,
    );
  });

  testWidgets('error shows Retry that closes then retries', (tester) async {
    final h = await pump(tester, none(LyricsNoneReason.error));
    expect(find.text('The last search failed'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Lyrics for this song'), findsNothing);
    expect(h.log, ['retry']);
  });

  testWidgets('instrumental', (tester) async {
    await pump(tester, none(LyricsNoneReason.instrumental));
    expect(find.text('Instrumental'), findsOneWidget);
  });

  testWidgets('lyrics off shows no status line', (tester) async {
    await pump(tester, none(LyricsNoneReason.off));
    expect(find.textContaining('No lyrics on this device'), findsNothing);
  });
}
