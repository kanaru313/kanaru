import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_dialog.dart';
import 'package:kanaru/shared/widgets/track_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../core/lyrics/online/lookup_test_harness.dart';

void main() {
  /// The song of [fakeTarget] as a library row.
  const song = TrackListItem(
    id: 1,
    path: '/music/song.flac',
    title: 'Song',
    artist: 'Artist',
    album: 'Alb',
    durationMs: 200000,
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('the row can go away while the menu is open and the pick still '
      'lands', (tester) async {
    tester.view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = FakeLyricsProvider()
      ..searchResult = [fakeCandidate(remoteId: 'good')];
    final h = await createHarness([LyricsProviderRegistration(fake)]);
    final rowShown = ValueNotifier(true);
    addTearDown(rowShown.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: rowShown,
              builder: (_, shown, _) => shown
                  ? TrackActionsRegion(
                      trackId: song.id,
                      path: song.path,
                      song: song,
                      onQueueAction: (_) {},
                      child: const Text('row'),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('row'), buttons: kSecondaryButton);
    await settle(tester);
    expect(find.text('Find lyrics online…'), findsOneWidget);

    // A rescan rebuilds the row away while the menu is open.
    rowShown.value = false;
    await tester.pump();
    expect(find.text('row'), findsNothing);

    await tester.tap(find.text('Find lyrics online…'));
    await settle(tester);
    expect(find.byType(LyricsPickerDialog), findsOneWidget);

    await tester.tap(find.text('Use these lyrics'));
    await settle(tester);

    expect(find.byType(LyricsPickerDialog), findsNothing);
    final pin = await tester.runAsync(
      () => h.db.watchLyricsPin(fakeTarget.trackKey).first,
    );
    expect(pin?.remoteId, 'good');
  });
}
