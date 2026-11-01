import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' show AlbumKey;
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/enqueue_from_database.dart';
import 'package:kanaru/shared/queue_host.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../features/library/browse_test_data.dart';
import '../features/library/library_test_harness.dart';
import '../features/playlists/playlist_test_data.dart';

const _tracks = [
  TestTrack('a1', artist: 'Ann', album: 'Alpha', track: 1),
  TestTrack('a2', artist: 'Ann', album: 'Alpha', track: 2),
  TestTrack('b1', artist: 'Bob', album: 'Beta', track: 1),
];
const _alpha = AlbumKey('ann', 'alpha');

void main() {
  List<String> queue(LibraryHarness h) => [
    for (final t in h.container.read(playerServiceProvider).queue.tracks)
      t.title,
  ];

  /// Mounts a probe widget over the harness's providers, captures a host, a
  /// ref and the probe's context, then removes the probe so both are gone.
  Future<(QueueHost, WidgetRef, BuildContext)> openAndLeave(
    WidgetTester tester,
    LibraryHarness h,
  ) async {
    await openWithTracks(tester, h, _tracks, location: '/albums');
    late StateSetter setShown;
    var shown = true;
    late BuildContext context;
    late WidgetRef ref;
    late QueueHost host;
    late NavigatorState rootNavigator;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, set) {
                setShown = set;
                if (!shown) return const SizedBox();
                // A nested navigator, so the probe's own navigator is not the
                // root one.
                return Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => Consumer(
                      builder: (probe, probeRef, _) {
                        context = probe;
                        ref = probeRef;
                        rootNavigator = Navigator.of(
                          probe,
                          rootNavigator: true,
                        );
                        host = QueueHost.captured(
                          container: h.container,
                          messenger: ScaffoldMessenger.of(probe),
                          l10n: probe.l10n,
                          dialogContext: rootNavigator.context,
                          db: h.db,
                        );
                        return const Text('probe');
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    setShown(() => shown = false);
    await tester.pump();
    expect(context.mounted, isFalse);
    return (host, ref, context);
  }

  testWidgets('enqueueAlbum in a host queues with an unmounted context', (
    tester,
  ) async {
    final h = LibraryHarness();
    final (host, ref, context) = await openAndLeave(tester, h);

    QueueHost.run(
      host,
      () => enqueueAlbum(ref, context, QueueAction.addToQueue, _alpha, 'Alpha'),
    );
    await settleIo(tester, h);

    expect(queue(h), ['a1', 'a2']);
    expect(find.text('Playing: Alpha'), findsOneWidget);
  });

  testWidgets('enqueueAlbum without a host drops an unmounted context', (
    tester,
  ) async {
    final h = LibraryHarness();
    final (_, ref, context) = await openAndLeave(tester, h);

    enqueueAlbum(ref, context, QueueAction.addToQueue, _alpha, 'Alpha');
    await settleIo(tester, h);

    expect(queue(h), isEmpty);
  });

  testWidgets('add to playlist in a host opens the picker on the root', (
    tester,
  ) async {
    final h = LibraryHarness();
    final (host, ref, context) = await openAndLeave(tester, h);
    final mix = await tester.runAsync(
      () => h.db.createPlaylist('Mix', now: 1, paths: const []),
    );
    final paths = await trackPaths(tester, h);

    QueueHost.run(
      host,
      () => enqueueAlbum(
        ref,
        context,
        QueueAction.addToPlaylist,
        _alpha,
        'Alpha',
      ),
    );
    await settleDb(tester);

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    // The root navigator holds the picker, not the probe's nested one.
    final root = Navigator.of(
      tester.element(dialog.hitTestable()),
      rootNavigator: true,
    );
    expect(Navigator.of(tester.element(dialog)), same(root));

    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: dialog, matching: find.byType(FilledButton)),
    );
    await settleDb(tester);

    expect(await storedPaths(tester, h, mix!), [paths['a1'], paths['a2']]);
  });

  testWidgets('playAlbumIn plays the album in page order without a ref', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/albums');

    await playAlbumIn(h.container, _alpha);
    await tester.pump();

    expect(queue(h), ['a1', 'a2']);
    expect(h.container.read(playerServiceProvider).queue.shuffled, isFalse);
  });

  testWidgets('playAlbumIn with shuffle shuffles the album', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/albums');

    await playAlbumIn(h.container, _alpha, shuffle: true);
    await tester.pump();

    expect(queue(h).toSet(), {'a1', 'a2'});
    expect(h.container.read(playerServiceProvider).queue.shuffled, isTrue);
  });
}
