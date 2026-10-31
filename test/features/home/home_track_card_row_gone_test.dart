import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/home/home_track_card.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

const _song = TrackListItem(id: 1, path: '/m/1.flac', title: 'one');

void main() {
  for (final label in ['Play next', 'Add to queue']) {
    testWidgets('$label runs when the card left the tree while the song '
        'modal was open', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final shown = ValueNotifier<bool>(true);
      addTearDown(shown.dispose);
      final container = ProviderContainer(
        overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: shown,
                builder: (_, on, _) => on
                    ? const SizedBox(
                        width: 200,
                        height: 260,
                        child: HomeTrackCard(row: [_song], index: 0),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('one'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);

      // A refresh of the shelf drops the card while the modal stays open.
      shown.value = false;
      await tester.pump();
      expect(find.byType(HomeTrackCard), findsNothing);

      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      final queue = [
        for (final t in container.read(playerServiceProvider).queue.tracks)
          t.title,
      ];
      expect(queue, ['one']);
      expect(find.text('Playing: one'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
