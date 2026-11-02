import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/database/playlist_page_queries.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/playlists/playlist_modal/playlist_actions_region.dart';
import 'package:kanaru/features/playlists/playlist_modal/playlist_more_button.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../library/library_test_harness.dart';

/// What a pumped host holds.
class ModalHost {
  ModalHost(this.router);
  final GoRouter router;

  /// The row that opens the modal; false removes it from the tree.
  final shown = ValueNotifier<bool>(true);

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

/// Mounts a row (right click opens the playlist modal of [id]) on a router
/// with the playlist routes, over the providers of [h]. The summary the modal
/// opens with is the playlist as stored now unless [snapshot] says other.
Future<ModalHost> pumpModalHost(
  WidgetTester tester,
  LibraryHarness h, {
  required int id,
  bool showGoTo = true,
  bool withMoreButton = false,
  Future<void> Function()? beforeRead,
  PlaylistSummary? snapshot,
  Size size = const Size(1000, 800),
}) async {
  await h.pump(tester, hasRoots: true);
  tester.view.physicalSize = size;
  final head = await tester.runAsync(() => h.db.playlistPageHead(id));
  final summary = snapshot ?? head!.playlist;
  final coverKeys = head?.coverKeys ?? const <String>[];
  late final ModalHost host;
  Widget page(String label) => Scaffold(body: Text(label));
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => ValueListenableBuilder<bool>(
          valueListenable: host.shown,
          builder: (_, shown, _) => Scaffold(
            body: shown
                ? Column(
                    children: [
                      PlaylistActionsRegion(
                        playlist: summary,
                        coverKeys: coverKeys,
                        showGoTo: showGoTo,
                        beforeRead: beforeRead,
                        child: const Focus(
                          autofocus: true,
                          child: SizedBox(
                            width: 300,
                            height: 80,
                            child: Text('tile'),
                          ),
                        ),
                      ),
                      if (withMoreButton)
                        PlaylistMoreButton(
                          playlist: summary,
                          coverKeys: coverKeys,
                          showGoTo: showGoTo,
                          beforeRead: beforeRead,
                        ),
                    ],
                  )
                : const SizedBox(),
          ),
        ),
      ),
      GoRoute(path: '/playlists', builder: (_, _) => page('playlists page')),
      GoRoute(
        path: '/playlists/:id',
        builder: (_, state) => page('playlist ${state.pathParameters['id']}'),
      ),
      GoRoute(path: '/favorites', builder: (_, _) => page('favorites page')),
    ],
  );
  host = ModalHost(router);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: h.container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return host;
}

/// Lets the modal's reads finish and its animations end.
Future<void> settleModal(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
  }
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Opens the playlist modal of the row with a right click.
Future<void> openPlaylistModalOf(WidgetTester tester) async {
  await tester.tap(find.text('tile'), buttons: kSecondaryButton);
  await settleModal(tester);
}

/// Taps the row with action [id] and waits for what it starts.
Future<void> tapModalAction(WidgetTester tester, String id) async {
  await tester.tap(modalAction(id));
  await settleModal(tester);
}

/// The row of the open modal with action [id].
Finder modalAction(String id) =>
    find.byKey(ValueKey('context-modal-action-$id'));

/// Titles of the queue of the player, in order.
List<String> queueTitles(LibraryHarness h) => [
  for (final t in h.container.read(playerServiceProvider).queue.tracks) t.title,
];
