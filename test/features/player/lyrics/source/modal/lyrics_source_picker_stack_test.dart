import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart' show AlertDialog;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/source/lyrics_source_button.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_dialog.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';

import '../../../../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../lyrics_source_button_harness.dart';
import 'lyrics_source_modal_test_harness.dart';

void main() {
  final none = fakeResolution(LyricsNone(modalUri, LyricsNoneReason.noLyrics));
  final found = fakeCandidate(remoteId: 'good');

  Future<SourceModalHarness> openStack(
    WidgetTester tester, {
    bool tapFind = true,
    bool consent = true,
  }) async {
    final fake = FakeLyricsProvider()..searchResult = [found];
    final h = await pumpSourceModal(
      tester,
      none,
      manualConsent: consent,
      records: [modalRecord('plugin-a', 'A')],
      overrides: [
        lyricsProvidersProvider.overrideWithValue([
          LyricsProviderRegistration(fake),
        ]),
      ],
    );
    if (tapFind) {
      await tester.tap(find.text('Find lyrics online…'));
      await _settle(tester);
    }
    return h;
  }

  testWidgets('Find opens the picker over the lyrics modal', (tester) async {
    await openStack(tester);
    expect(find.byType(LyricsPickerDialog), findsOneWidget);
    expect(find.text('Lyrics for this song'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('the back arrow returns to the lyrics modal', (tester) async {
    await openStack(tester);
    await tester.tap(find.byTooltip('Back'));
    await _settle(tester);
    expect(find.byType(LyricsPickerDialog), findsNothing);
    expect(find.text('Lyrics for this song'), findsOneWidget);
  });

  testWidgets('Esc closes only the picker', (tester) async {
    await openStack(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.byType(LyricsPickerDialog), findsNothing);
    expect(find.text('Lyrics for this song'), findsOneWidget);
  });

  testWidgets('Use closes both modals and pins the lyrics', (tester) async {
    final h = await openStack(tester);
    await tester.tap(find.byType(SelectionRow).last);
    await _settle(tester);
    // The previewed row shows the check mark.
    expect(
      find.descendant(
        of: find.byType(LyricsPickerDialog),
        matching: find.byIcon(AppIcons.check),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Use these lyrics'));
    await _settle(tester);
    expect(find.byType(LyricsPickerDialog), findsNothing);
    expect(find.text('Lyrics for this song'), findsNothing);
    expect(h.log, ['pick good']);
  });

  testWidgets('a track change closes the whole stack', (tester) async {
    final h = await openStack(tester);
    h.resolution.emit(
      fakeResolution(LyricsNone(otherTrack.uri, LyricsNoneReason.noLyrics)),
    );
    await _settle(tester);
    expect(find.byType(LyricsPickerDialog), findsNothing);
    expect(find.text('Lyrics for this song'), findsNothing);
  });

  testWidgets('a double activation of Find opens one picker', (tester) async {
    await openStack(tester, tapFind: false);
    final row = find.widgetWithText(SelectionRow, 'Find lyrics online…');
    final onTap = tester.widget<SelectionRow>(row).onTap!;
    onTap();
    onTap();
    await _settle(tester);
    expect(find.byType(LyricsPickerDialog), findsOneWidget);
  });

  testWidgets('Cancel on the consent notice keeps the modal and opens no '
      'picker', (tester) async {
    final h = await openStack(tester, consent: false);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(find.byType(LyricsPickerDialog), findsNothing);
    expect(find.text('Lyrics for this song'), findsOneWidget);
    expect(h.log, isEmpty);
  });

  testWidgets('Use shows the snackbar once both modals are closed', (
    tester,
  ) async {
    await openStack(tester);
    await tester.tap(find.byType(SelectionRow).last);
    await _settle(tester);
    await tester.tap(find.text('Use these lyrics'));
    await _settle(tester);
    expect(find.text('Lyrics for this song'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(openerScaffold),
        matching: find.text('Lyrics chosen for this song'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the header button stays open while the picker is up', (
    tester,
  ) async {
    final fake = FakeLyricsProvider()..searchResult = [found];
    final h = await pumpLyricsButton(
      tester,
      none,
      records: [modalRecord('plugin-a', 'A')],
      overrides: [
        initialSettingsProvider.overrideWithValue(
          const AppSettings(
            onlineLyrics: OnlineLyricsPrefs(
              autoFetch: true,
              autoConsent: true,
              manualConsent: true,
            ),
          ),
        ),
        lyricsProvidersProvider.overrideWithValue([
          LyricsProviderRegistration(fake),
        ]),
      ],
    );
    await tester.tap(find.byType(LyricsSourceButton));
    await _settle(tester);
    await tester.tap(find.text('Find lyrics online…'));
    await _settle(tester);
    expect(find.byType(LyricsPickerDialog), findsOneWidget);
    expect(h.events, [true]);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(h.events, [true]);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(h.events, [true, false]);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}
