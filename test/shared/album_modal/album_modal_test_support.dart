import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/database/album_links_provider.dart';
import 'package:kanaru/core/database/library_browse_album_links.dart';
import 'package:kanaru/core/database/library_browse_rows.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/album_modal/album_actions_region.dart';
import 'package:kanaru/shared/album_modal/album_more_button.dart';
import 'package:kanaru/shared/enqueue_from_database.dart';
import 'package:kanaru/shared/show_in_file_manager.dart';
import 'package:kanaru/shared/widgets/library_grid/album_tile_data.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/settle_modal.dart';
export '../../support/settle_modal.dart' show settleModal;

const testAlbumKey = AlbumKey('ann', 'al');
const testAlbum = AlbumTileData(
  key: testAlbumKey,
  title: 'Al',
  artist: 'Ann',
  year: 1999,
);

typedef Artists = List<({String key, String name})>;

Artists artistsOf(List<String> names) => [
  for (final n in names) (key: n.toLowerCase(), name: n),
];

/// Links of [testAlbum] with [artists] and [folders].
AlbumLinks linksOf({
  Artists? artists,
  List<AlbumFolder> folders = const [
    AlbumFolder(path: '/m/Rock', songCount: 3, samplePath: '/m/Rock/1.flac'),
  ],
}) => AlbumLinks(
  summary: const AlbumSummary(
    key: testAlbumKey,
    title: 'Al',
    artist: 'Ann',
    year: 1999,
    trackCount: 3,
    durationMs: 600000,
    addedAt: 1,
  ),
  artists: artists ?? artistsOf(['Ann']),
  folders: folders,
);

/// What a pumped host recorded.
class AlbumHost {
  AlbumHost(this.router);
  final GoRouter router;

  /// The tile that opens the modal; false removes it from the tree.
  final shown = ValueNotifier<bool>(true);
  final queueActions = <QueueAction>[];
  final shownInFileManager = <String>[];

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

/// Mounts a tile (right click opens the album modal) on a router, with the
/// links of the album answered by [links] and a fake file manager. Uses
/// [container] when given (then [links] is ignored). [pageArtistKey] is the
/// artist whose page lists the tile.
Future<AlbumHost> pumpAlbumHost(
  WidgetTester tester, {
  AlbumLinks? links,
  ProviderContainer? container,
  bool showAlbum = true,
  String? pageArtistKey,
  bool withMoreButton = false,
  AlbumTileData album = testAlbum,
  bool enqueueForReal = false,
  void Function()? onLinksRead,
  Size size = const Size(1000, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late final AlbumHost host;
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
                        builder: (context, ref, _) => AlbumActionsRegion(
                          album: album,
                          showAlbum: showAlbum,
                          pageArtistKey: pageArtistKey,
                          onQueueAction: enqueueForReal
                              ? (a) => enqueueAlbum(
                                  ref,
                                  context,
                                  a,
                                  album.key,
                                  album.title,
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
                        AlbumMoreButton(
                          album: testAlbum,
                          showAlbum: showAlbum,
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
  host = AlbumHost(router);
  final app = MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
  await tester.pumpWidget(
    container != null
        ? UncontrolledProviderScope(container: container, child: app)
        : ProviderScope(
            overrides: [
              albumModalLinksProvider(testAlbumKey).overrideWith((ref) async {
                onLinksRead?.call();
                return links;
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

/// Opens the album modal of the tile with a right click.
Future<void> openAlbumModalOf(WidgetTester tester) async {
  await tester.tap(find.text('tile'), buttons: kSecondaryButton);
  await settleModal(tester);
}

/// Taps the row labelled [label] and waits for what it starts.
Future<void> tapAlbumRow(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await settleModal(tester);
}

/// The row of the open modal with action [id].
Finder albumModalAction(String id) =>
    find.byKey(ValueKey('context-modal-action-$id'));
