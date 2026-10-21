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
      // Messages show one after the other: let this one go.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

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
      expect(queue(h), [
        'a1',
        'a2',
        'b1',
        'z',
      ], reason: 'the long press is not a tap: the row did not play');
      expect(
        h.container.read(playerServiceProvider).queue.current?.title,
        'a1',
      );
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
      expect(find.text('Playing: b1'), findsOneWidget);
      expect(find.text('Playing next: b1'), findsNothing);
    });

    testWidgets('Add to queue on an empty queue says it plays', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/songs');

      await rightClick(tester, find.text('b1'));
      await pick(tester, h, 'Add to queue');

      expect(queue(h), ['b1']);
      expect(find.text('Playing: b1'), findsOneWidget);
    });

    testWidgets('album tracks have the menu too', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: albumLocation(_alpha));

      await rightClick(tester, find.text('a2'));
      await pick(tester, h, 'Add to queue');

      expect(queue(h), ['a2']);
      expect(find.text('Playing: a2'), findsOneWidget);
    });

    testWidgets('artist songs have the menu too', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: artistLocation('ann'));

      await rightClick(tester, find.text('a2'));
      await pick(tester, h, 'Play next');

      expect(queue(h), ['a2']);
      expect(find.text('Playing: a2'), findsOneWidget);
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
      expect(find.text('Playing: Alpha'), findsOneWidget);
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
      expect(find.text('Playing: Beta'), findsOneWidget);
    });

    testWidgets('a grid tile queues the album', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/albums');

      await tester.longPress(find.text('Alpha'));
      await tester.pumpAndSettle();
      await pick(tester, h, 'Add to queue');

      expect(queue(h), ['a1', 'a2']);
      expect(find.text('Playing: Alpha'), findsOneWidget);
    });
  });

  group('artists', () {
    testWidgets('a list tile queues the songs of the artist', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/artists');

      await rightClick(tester, find.text('Ann'));
      await pick(tester, h, 'Play next');

      expect(queue(h), ['a1', 'a2']);
      expect(find.text('Playing: Ann'), findsOneWidget);
    });

    testWidgets('queue the songs in the order of the artist page', (
      tester,
    ) async {
      final h = LibraryHarness();
      // Raw order (as stored) differs from the page: the owned albums go by
      // year (Beta before Alpha), then the albums appeared on.
      await openWithTracks(tester, h, const [
        TestTrack(
          'alpha1',
          artist: 'Ann',
          album: 'Alpha',
          albumArtist: 'Ann',
          year: 2020,
          track: 1,
        ),
        TestTrack(
          'alpha2',
          artist: 'Ann',
          album: 'Alpha',
          albumArtist: 'Ann',
          year: 2020,
          track: 2,
        ),
        TestTrack('guest', artist: 'X; Ann', album: 'Theirs', albumArtist: 'X'),
        TestTrack(
          'beta1',
          artist: 'Ann',
          album: 'Beta',
          albumArtist: 'Ann',
          year: 2010,
          track: 1,
        ),
        TestTrack('loose', artist: 'Ann'),
      ], location: '/artists');

      await rightClick(tester, find.text('Ann'));
      await pick(tester, h, 'Add to queue');

      const order = ['beta1', 'alpha1', 'alpha2', 'guest', 'loose'];
      expect(queue(h), order);

      // The page plays the same list.
      goTo(tester, h, artistLocation('ann'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Play'));
      await tester.pump();
      expect([
        for (final t in h.container.read(playerServiceProvider).queue.original)
          t.title,
      ], order);
    });

    testWidgets('the header button queues the artist', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: artistLocation('bob'));

      await tester.tap(find.byTooltip('Queue actions'));
      await tester.pumpAndSettle();
      await pick(tester, h, 'Add to queue');

      expect(queue(h), ['b1']);
      expect(find.text('Playing: Bob'), findsOneWidget);
    });
  });

  group('enqueueTracks', () {
    late WidgetRef ref;
    late BuildContext context;
    late ProviderContainer container;

    Future<void> pumpHost(WidgetTester tester, {Widget? extra}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioBackendProvider.overrideWithValue(FakeAudioBackend()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (c, r, _) {
                  ref = r;
                  context = c;
                  return extra ?? const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      container = ProviderScope.containerOf(context);
    }

    List<String> titles() => [
      for (final t in container.read(playerServiceProvider).queue.tracks)
        t.title,
    ];
    Track track(String name) => Track.fromPath('/m/$name.mp3');
    Future<void> enqueue(
      Future<List<Track>> Function() read,
      String label, {
      ScaffoldMessengerState? messenger,
    }) => enqueueTracks(
      ref,
      messenger ?? ScaffoldMessenger.of(context),
      context.l10n,
      QueueAction.addToQueue,
      read,
      label,
    );

    testWidgets('reach the queue in click order', (tester) async {
      await pumpHost(tester);

      // The first read is slower than the second.
      final slow = Completer<List<Track>>();
      unawaited(enqueue(() => slow.future, 'slow'));
      unawaited(enqueue(() async => [track('fast')], 'fast'));
      await tester.pump();
      expect(titles(), isEmpty, reason: 'the fast one waits for the slow one');

      slow.complete([track('slow1'), track('slow2')]);
      await tester.pump();
      await tester.pump();

      expect(titles(), ['slow1', 'slow2', 'fast']);
    });

    testWidgets('a failed read says so and the next pick still runs', (
      tester,
    ) async {
      await pumpHost(tester);

      unawaited(enqueue(() async => throw StateError('db gone'), 'bad'));
      unawaited(enqueue(() async => [track('next')], 'next'));
      await tester.pump();
      await tester.pump();

      expect(titles(), ['next']);
      expect(
        find.text('Something went wrong. See the log for details.'),
        findsOneWidget,
      );
    });

    testWidgets('a messenger that is gone does not stop later picks', (
      tester,
    ) async {
      late ScaffoldMessengerState gone;
      await pumpHost(
        tester,
        extra: ScaffoldMessenger(
          child: Builder(
            builder: (c) {
              gone = ScaffoldMessenger.of(c);
              return const SizedBox();
            },
          ),
        ),
      );
      // Remove the nested messenger from the tree.
      await tester.pumpWidget(const SizedBox());
      await pumpHost(tester);

      // Both the report of the result and of the failure throw.
      await enqueue(() async => [track('lost')], 'lost', messenger: gone);
      await enqueue(() async => [track('next')], 'next');
      await tester.pump();

      expect(titles(), ['lost', 'next']);
      expect(find.text('Playing: lost'), findsNothing);
    });

    testWidgets('does not hide the message showing', (tester) async {
      await pumpHost(tester);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan finished'),
          duration: Duration(minutes: 1),
        ),
      );
      await tester.pump();

      await enqueue(() async => [track('a')], 'a');
      await tester.pump();

      expect(find.text('Scan finished'), findsOneWidget);
    });
  });
}
