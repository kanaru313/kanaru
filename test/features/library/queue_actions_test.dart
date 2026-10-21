import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' show AlbumKey;
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/library/play_tracks.dart';
import 'package:kanaru/features/library/widgets/queue_actions_menu.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/library/library_route_keys.dart';

import 'browse_test_data.dart';
import '../../core/player/fake_audio_backend.dart';
import 'library_test_harness.dart';

const _tracks = [
  TestTrack('a1', artist: 'Ann', album: 'Alpha', track: 1),
  TestTrack('a2', artist: 'Ann', album: 'Alpha', track: 2),
  TestTrack('b1', artist: 'Bob', album: 'Beta', track: 1),
  TestTrack('z', artist: 'Zed'),
];

const _alpha = AlbumKey('ann', 'alpha');

void main() {
  List<String> queue(LibraryHarness h) => [
    for (final t in h.container.read(playerServiceProvider).queue.tracks)
      t.title,
  ];

  Future<void> rightClick(WidgetTester tester, Finder target) async {
    await tester.tap(target, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, LibraryHarness h, String item) async {
    await tester.tap(find.text(item));
    await settleIo(tester, h);
  }

  /// Starts the queue with the song [title] already playing.
  Future<void> startWith(
    WidgetTester tester,
    LibraryHarness h,
    String title,
  ) async {
    await tester.tap(find.text(title));
    await tester.pump();
    expect(queue(h), isNotEmpty);
  }

  group('song rows', () {
    testWidgets('right click offers Play next and Add to queue', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/songs');
      await startWith(tester, h, 'a1');
      expect(queue(h), ['a1', 'a2', 'b1', 'z']);

      await rightClick(tester, find.text('z'));
      expect(find.text('Play next'), findsOneWidget);
      expect(find.text('Add to queue'), findsOneWidget);
      await pick(tester, h, 'Play next');

      expect(queue(h), ['a1', 'z', 'a2', 'b1', 'z']);
      expect(find.text('Playing next: z'), findsOneWidget);

      await rightClick(tester, find.text('b1'));
      await pick(tester, h, 'Add to queue');

      expect(queue(h), ['a1', 'z', 'a2', 'b1', 'z', 'b1']);
      expect(find.text('Added to queue: b1'), findsOneWidget);
    });

    testWidgets('a long press opens the menu', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/songs');
      await startWith(tester, h, 'a1');

      await tester.longPress(find.text('z'));
      await tester.pumpAndSettle();
      await pick(tester, h, 'Add to queue');

      expect(queue(h).last, 'z');
      expect(find.text('Added to queue: z'), findsOneWidget);
    });

    testWidgets('with an empty queue the song starts playing', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/songs');

      await rightClick(tester, find.text('b1'));
      await pick(tester, h, 'Play next');

      expect(queue(h), ['b1']);
      expect(h.container.read(playerServiceProvider).playing, isTrue);
    });

    testWidgets('album tracks have the menu too', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: albumLocation(_alpha));

      await rightClick(tester, find.text('a2'));
      await pick(tester, h, 'Add to queue');

      expect(queue(h), ['a2']);
      expect(find.text('Added to queue: a2'), findsOneWidget);
    });

    testWidgets('artist songs have the menu too', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: artistLocation('ann'));

      await rightClick(tester, find.text('a2'));
      await pick(tester, h, 'Play next');

      expect(queue(h), ['a2']);
      expect(find.text('Playing next: a2'), findsOneWidget);
    });
  });

  group('albums', () {
    testWidgets('the header button queues the whole album', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: albumLocation(_alpha));

      await tester.tap(find.byTooltip('Queue actions'));
      await tester.pumpAndSettle();
      await pick(tester, h, 'Play next');

      expect(queue(h), ['a1', 'a2']);
      expect(find.text('Playing next: Alpha'), findsOneWidget);
    });

    testWidgets('a list tile queues the album', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/albums');
      h.container
          .read(settingsProvider.notifier)
          .setAlbumsView(AlbumsView.list);
      await tester.pumpAndSettle();

      await rightClick(tester, find.text('Beta'));
      await pick(tester, h, 'Add to queue');

      expect(queue(h), ['b1']);
      expect(find.text('Added to queue: Beta'), findsOneWidget);
    });

    testWidgets('a grid tile queues the album', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/albums');

      await tester.longPress(find.text('Alpha'));
      await tester.pumpAndSettle();
      await pick(tester, h, 'Add to queue');

      expect(queue(h), ['a1', 'a2']);
      expect(find.text('Added to queue: Alpha'), findsOneWidget);
    });
  });

  group('artists', () {
    testWidgets('a list tile queues the songs of the artist', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/artists');

      await rightClick(tester, find.text('Ann'));
      await pick(tester, h, 'Play next');

      expect(queue(h), ['a1', 'a2']);
      expect(find.text('Playing next: Ann'), findsOneWidget);
    });

    testWidgets('the header button queues the artist', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: artistLocation('bob'));

      await tester.tap(find.byTooltip('Queue actions'));
      await tester.pumpAndSettle();
      await pick(tester, h, 'Add to queue');

      expect(queue(h), ['b1']);
      expect(find.text('Added to queue: Bob'), findsOneWidget);
    });
  });

  testWidgets('quick actions reach the queue in click order', (tester) async {
    final backend = FakeAudioBackend();
    late WidgetRef ref;
    late BuildContext context;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioBackendProvider.overrideWithValue(backend)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (c, r, _) {
                ref = r;
                context = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(context);
    List<String> titles() => [
      for (final t in container.read(playerServiceProvider).queue.tracks)
        t.title,
    ];
    Track track(String name) => Track.fromPath('/m/$name.mp3');
    void enqueue(Future<List<Track>> Function() read, String label) =>
        unawaited(
          enqueueTracks(
            ref,
            ScaffoldMessenger.of(context),
            context.l10n,
            QueueAction.addToQueue,
            read,
            label,
          ),
        );

    // The first read is slower than the second.
    final slow = Completer<List<Track>>();
    enqueue(() => slow.future, 'slow');
    enqueue(() async => [track('fast')], 'fast');
    await tester.pump();
    expect(titles(), isEmpty, reason: 'the fast one waits for the slow one');

    slow.complete([track('slow1'), track('slow2')]);
    await tester.pump();
    await tester.pump();

    expect(titles(), ['slow1', 'slow2', 'fast']);
  });
}
