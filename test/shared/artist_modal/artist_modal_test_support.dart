import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/database/library_browse_album_links.dart';
import 'package:kanaru/core/database/library_browse_rows.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/artist_modal/artist_actions_region.dart';
import 'package:kanaru/shared/artist_modal/artist_modal_links.dart';
import 'package:kanaru/shared/artist_modal/artist_more_button.dart';
import 'package:kanaru/shared/artist_page/artist_page_sections.dart';
import 'package:kanaru/shared/artist_page/enqueue_artist.dart';
import 'package:kanaru/shared/artist_summaries.dart';
import 'package:kanaru/shared/show_in_file_manager.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

const testArtist = ArtistSummary(
  key: 'ann',
  name: 'Ann',
  songCount: 12,
  albumCount: 3,
  durationMs: 3600000,
);

/// An album titled [title] of the artist ('ann' unless [artist] says other).
AlbumSummary albumOf(String title, {int? year, String artist = 'ann'}) =>
    AlbumSummary(
      key: AlbumKey(artist, title.toLowerCase()),
      title: title,
      artist: artist,
      year: year,
      trackCount: 4,
      addedAt: 1,
    );

/// [n] albums titled "Own 0" and so on.
List<AlbumSummary> ownAlbums(int n) => [
  for (var i = 0; i < n; i++) albumOf('Own $i', year: 2000 + i),
];

/// [n] albums titled "Other 0" and so on, by another artist.
List<AlbumSummary> otherAlbums(int n) => [
  for (var i = 0; i < n; i++) albumOf('Other $i', artist: 'bob'),
];

const _rockFolder = AlbumFolder(
  path: '/m/Rock',
  songCount: 12,
  samplePath: '/m/Rock/1.flac',
);

/// Links of [testArtist] with [own] and [appearsOn] albums and [folders];
/// [name] is the spelling the page of the artist uses.
ArtistLinks linksOf({
  List<AlbumSummary>? own,
  List<AlbumSummary>? appearsOn,
  List<AlbumFolder> folders = const [_rockFolder],
  String name = 'Ann',
}) => (
  sections: ArtistPageSections(
    name: name,
    albums: own ?? ownAlbums(1),
    songs: const [],
    appearsOn: appearsOn ?? const [],
  ),
  folders: folders,
);

/// What a pumped host recorded.
class ArtistHost {
  ArtistHost(this.router);
  final GoRouter router;

  /// The row that opens the modal; false removes it from the tree.
  final shown = ValueNotifier<bool>(true);
  final queueActions = <QueueAction>[];
  final shownInFileManager = <String>[];

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

/// Mounts a row (right click opens the artist modal) on a router, with the
/// links of the artist answered by [links] and a fake file manager. Uses
/// [container] when given (then [links] is ignored).
Future<ArtistHost> pumpArtistHost(
  WidgetTester tester, {
  ArtistLinks? links,
  ProviderContainer? container,
  bool showArtist = true,
  bool withMoreButton = false,
  ArtistSummary artist = testArtist,
  bool enqueueForReal = false,
  void Function()? onLinksRead,

  /// When given, the links stay loading until it completes.
  Completer<ArtistLinks?>? gate,
  Size size = const Size(1000, 800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late final ArtistHost host;
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
                      Consumer(
                        builder: (context, ref, _) => ArtistActionsRegion(
                          artist: artist,
                          showArtist: showArtist,
                          onQueueAction: enqueueForReal
                              ? (a) => enqueueArtist(
                                  ref,
                                  context,
                                  a,
                                  artist.key,
                                  artist.name,
                                )
                              : host.queueActions.add,
                          child: const Focus(
                            autofocus: true,
                            child: SizedBox(
                              width: 300,
                              height: 80,
                              child: Text('tile'),
                            ),
                          ),
                        ),
                      ),
                      if (withMoreButton)
                        ArtistMoreButton(
                          artist: artist,
                          showArtist: showArtist,
                          onQueueAction: host.queueActions.add,
                        ),
                    ],
                  )
                : const SizedBox(),
          ),
        ),
      ),
    ],
  );
  host = ArtistHost(router);
  final app = MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  );
  await tester.pumpWidget(
    container != null
        ? UncontrolledProviderScope(container: container, child: app)
        : ProviderScope(
            overrides: [
              artistModalLinksProvider(artist.key).overrideWith((ref) async {
                onLinksRead?.call();
                return gate == null ? links : gate.future;
              }),
              showInFileManagerProvider.overrideWithValue((path) async {
                host.shownInFileManager.add(path);
                return true;
              }),
            ],
            child: app,
          ),
  );
  return host;
}

/// Lets the modal's reads finish and its animations end.
Future<void> settleArtistModal(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Opens the artist modal of the row with a right click.
Future<void> openArtistModalOf(WidgetTester tester) async {
  await tester.tap(find.text('tile'), buttons: kSecondaryButton);
  await settleArtistModal(tester);
}

/// Taps the row labelled [label] and waits for what it starts.
Future<void> tapArtistRow(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await settleArtistModal(tester);
}

/// The row of the open modal with action [id].
Finder artistModalAction(String id) =>
    find.byKey(ValueKey('context-modal-action-$id'));
