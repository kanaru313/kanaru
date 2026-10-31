import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/home/home_tile_metrics.dart';
import 'package:kanaru/features/home/home_track_card.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

const _song = TrackListItem(id: 1, path: '/m/1.flac', title: 'one');

void main() {
  testWidgets('Add to playlist opens the picker and adds when the card left '
      'the tree while the song modal was open', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = LibraryDatabase(NativeDatabase.memory());
    final playlistId = (await tester.runAsync(
      () => db.createPlaylist('Mix', now: 1, paths: const []),
    ))!;
    final shown = ValueNotifier<bool>(true);
    addTearDown(shown.dispose);
    final container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        libraryDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await tester.runAsync(db.close);
    });
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
                      width: homeShelfTileWidth,
                      height: 300,
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

    shown.value = false;
    await tester.pump();
    expect(find.byType(HomeTrackCard), findsNothing);

    await tester.tap(find.text('Add to playlist…'));
    await tester.pumpAndSettle();
    final mix = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Mix'),
    );
    expect(mix, findsOneWidget);
    await tester.tap(mix);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    final page = await tester.runAsync(() => db.playlistPage(playlistId));
    expect([for (final e in page!.entries) e.path], ['/m/1.flac']);
    expect(tester.takeException(), isNull);
  });
}
