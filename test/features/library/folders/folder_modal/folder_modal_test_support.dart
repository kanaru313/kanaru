import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/indexer/excluded_folders_controller.dart';
import 'package:kanaru/features/library/folders/folder_modal/folder_actions_region.dart';
import 'package:kanaru/features/library/folders/folder_modal/folder_modal_links.dart';
import 'package:kanaru/features/library/folders/folder_modal/folder_more_button.dart';
import 'package:kanaru/features/library/folders/folder_tree.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/show_in_file_manager.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../support/settle_modal.dart';
export '../../../../support/settle_modal.dart' show settleModal;
export 'package:kanaru/core/indexer/excluded_folders_controller.dart'
    show ExclusionConflict, ExclusionResult;

FolderNode makeFolderNode({
  String path = '/m/Rock',
  String name = 'Rock',
  String rootPath = '/m',
  String label = 'Rock',
  bool ambiguousRoot = false,
  int directSongs = 1,
  String? directCoverKey,
  String? coverKey,
  int songs = 3,
  int subfolders = 2,
  List<FolderNode> children = const [],
}) => FolderNode(
  path: path,
  name: name,
  rootPath: rootPath,
  label: label,
  ambiguousRoot: ambiguousRoot,
  directSongs: directSongs,
  directCoverKey: directCoverKey,
  coverKey: coverKey,
  songs: songs,
  subfolders: subfolders,
  children: children,
);

final testFolder = makeFolderNode();

const FolderStats testStats = (
  durationMs: 600000,
  songCount: 3,
  samplePath: '/m/Rock/1.flac',
);

class FakeExcludedFoldersController extends Fake
    implements ExcludedFoldersController {
  final List<String> excluded = [];
  ExclusionResult nextResult = (rejection: null, conflict: null);

  @override
  Future<ExclusionResult> add(String path) async {
    excluded.add(path);
    return nextResult;
  }
}

/// What a pumped host recorded.
class FolderHost {
  FolderHost(this.router, {FakeExcludedFoldersController? excludedController})
      : excludedController =
            excludedController ?? FakeExcludedFoldersController();
  final GoRouter router;
  final FakeExcludedFoldersController excludedController;

  /// The tile that opens the modal; false removes it from the tree.
  final shown = ValueNotifier<bool>(true);
  final queueActions = <QueueAction>[];
  final shownInFileManager = <String>[];
  List<String> get excludedFolders => excludedController.excluded;

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

/// Mounts a tile (right click opens the folder modal) on a router, with
/// statistics answered by [stats] and a fake file manager.
Future<FolderHost> pumpFolderHost(
  WidgetTester tester, {
  FolderNode? folder,
  FolderStats? stats = testStats,
  bool statsResolved = true,
  bool direct = false,
  bool showFolder = true,
  bool withMoreButton = false,
  FakeExcludedFoldersController? excludedController,
  ProviderContainer? container,
  Size size = const Size(1000, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final node = folder ?? testFolder;
  late final FolderHost host;

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
                      FolderActionsRegion(
                        folder: node,
                        direct: direct,
                        showFolder: showFolder,
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
                      if (withMoreButton)
                        FolderMoreButton(
                          folder: node,
                          direct: direct,
                          showFolder: showFolder,
                          onQueueAction: host.queueActions.add,
                        ),
                    ],
                  )
                : const SizedBox(),
          ),
        ),
      ),
      GoRoute(
        path: '/folders/:key',
        builder: (_, state) =>
            Scaffold(body: Text('folder page: ${state.pathParameters['key']}')),
      ),
    ],
  );

  final fakeExcluded = excludedController ?? FakeExcludedFoldersController();
  host = FolderHost(router, excludedController: fakeExcluded);
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
              folderModalStatsProvider((path: node.path, direct: direct))
                  .overrideWith((ref) async => statsResolved ? stats : null),
              showInFileManagerProvider.overrideWithValue((path) async {
                host.shownInFileManager.add(path);
                return true;
              }),
              excludedFoldersControllerProvider
                  .overrideWithValue(fakeExcluded),
            ],
            child: app,
          ),
  );

  return host;
}

/// Opens the folder modal of the tile with a right click.
Future<void> openFolderModalOf(WidgetTester tester) async {
  await tester.tap(find.text('tile'), buttons: kSecondaryButton);
  await settleModal(tester);
}

/// Taps the row labelled [label] and waits for modal animations to settle.
Future<void> tapFolderRow(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await settleModal(tester);
}

/// The row of the open modal with action [id].
Finder folderModalAction(String id) =>
    find.byKey(ValueKey('context-modal-action-$id'));
