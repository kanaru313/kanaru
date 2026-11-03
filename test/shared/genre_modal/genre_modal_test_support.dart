import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/database/library_browse_album_links.dart';
import 'package:kanaru/core/database/library_browse_rows.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/genre_modal/genre_actions_region.dart';
import 'package:kanaru/shared/genre_modal/genre_modal_links.dart';
import 'package:kanaru/shared/genre_modal/genre_more_button.dart';
import 'package:kanaru/shared/genre_summaries.dart';
import 'package:kanaru/shared/show_in_file_manager.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/settle_modal.dart';
export '../../support/settle_modal.dart' show settleModal;

const testGenre = GenreSummary(
  key: 'rock',
  name: 'Rock',
  songCount: 12,
  raws: ['Rock'],
  coverKeys: ['rock1', 'rock2'],
);

/// An album titled [title] of the genre.
AlbumSummary albumOf(String title, {int? year, String artist = 'ann'}) =>
    AlbumSummary(
      key: AlbumKey(artist, title.toLowerCase()),
      title: title,
      artist: artist,
      year: year,
      trackCount: 4,
      addedAt: 1,
    );

/// [n] albums titled "Album 0" and so on.
List<AlbumSummary> testAlbums(int n) => [
  for (var i = 0; i < n; i++) albumOf('Album $i', year: 2000 + i),
];

const _rockFolder = AlbumFolder(
  path: '/m/Rock',
  songCount: 12,
  samplePath: '/m/Rock/1.flac',
);

BrowseTrack testTrack(
  int id, {
  String title = 'Song',
  String path = '/m/Rock/1.flac',
  int? durationMs = 180000,
}) =>
    BrowseTrack(
      id: id,
      path: path,
      title: title,
      durationMs: durationMs,
    );

/// Links of [testGenre] with [albums], [tracks], [folders], and [durationMs].
GenreLinks linksOf({
  List<AlbumSummary>? albums,
  List<BrowseTrack>? tracks,
  List<AlbumFolder> folders = const [_rockFolder],
  int? durationMs = 2160000,
}) => (
  albums: albums ?? testAlbums(1),
  tracks: tracks ?? [testTrack(1)],
  folders: folders,
  durationMs: durationMs,
);

/// What a pumped host recorded.
class GenreHost {
  GenreHost(this.router);
  final GoRouter router;

  /// The row that opens the modal; false removes it from the tree.
  final shown = ValueNotifier<bool>(true);
  final queueActions = <QueueAction>[];
  final shownInFileManager = <String>[];

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

/// Mounts a row (right click opens the genre modal) on a router, with the
/// links of the genre answered by [links] and a fake file manager. Uses
/// [container] when given (then [links] is ignored).
Future<GenreHost> pumpGenreHost(
  WidgetTester tester, {
  GenreLinks? links,
  ProviderContainer? container,
  bool showGenre = true,
  bool withMoreButton = false,
  GenreSummary genre = testGenre,
  void Function()? onLinksRead,

  /// When given, the links stay loading until it completes.
  Completer<GenreLinks?>? gate,
  Size size = const Size(1000, 800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late final GenreHost host;
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
                        builder: (context, ref, _) => GenreActionsRegion(
                          genre: genre,
                          showGenre: showGenre,
                          onQueueAction: host.queueActions.add,
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
                        GenreMoreButton(
                          genre: genre,
                          showGenre: showGenre,
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
  host = GenreHost(router);
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
              genreModalLinksProvider(genre).overrideWith((ref) async {
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

/// Opens the genre modal of the row with a right click.
Future<void> openGenreModalOf(WidgetTester tester) async {
  await tester.tap(find.text('tile'), buttons: kSecondaryButton);
  await settleModal(tester);
}

/// Taps the row labelled [label] and waits for what it starts.
Future<void> tapGenreRow(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await settleModal(tester);
}

/// The row of the open modal with action [id].
Finder genreModalAction(String id) =>
    find.byKey(ValueKey('context-modal-action-$id'));
