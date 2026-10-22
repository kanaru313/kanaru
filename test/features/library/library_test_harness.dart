import 'dart:io';

import 'package:drift/drift.dart' show ApplyInterceptor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/database/library_browse_missing_roots.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/library_keys_provider.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';
import 'package:kanaru/core/indexer/library_roots_controller.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/shared/directory_picker_provider.dart';
import 'package:kanaru/shared/library_browse_refresh.dart';
import 'package:kanaru/features/library/onboarding/suggested_music_folder_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/indexer/fake_tag_reader.dart';
import '../../core/player/fake_audio_backend.dart';

/// The app under test with a memory database, a fake tag reader and a fake
/// audio backend.
class LibraryHarness {
  LibraryHarness({
    this.hasDatabase = true,
    this.suggestion,
    FakeTagReader? reader,
    this.overrides = const [],
    this.picker,
    this.rootsController,
    this.refreshInterval = Duration.zero,
    this.coverCacheDirectory,
    this.interceptor,
    this.rootIsDirectory,
  }) : reader = reader ?? FakeTagReader();

  final bool hasDatabase;

  /// Shortest time between reloads of the browse lists; zero reloads at once.
  final Duration refreshInterval;
  final String? suggestion;

  /// The cover thumbnail folder; covers are off without one.
  final String? coverCacheDirectory;

  /// Extra provider overrides, applied last.
  final List<Override> overrides;

  /// Replaces the fake picker (which answers from [picks]).
  final DirectoryPicker? picker;

  /// Replaces the roots controller (which otherwise counts its additions in
  /// flight for [settleIo]).
  final LibraryRootsController? rootsController;

  /// Answers whether a root is still a folder; roots in tests are made-up
  /// paths, so by default every one is.
  final Future<bool> Function(String)? rootIsDirectory;

  /// Sees every statement the database runs, when given.
  final QueryInterceptor? interceptor;

  late final LibraryDatabase db = LibraryDatabase(
    interceptor == null
        ? NativeDatabase.memory()
        : NativeDatabase.memory().interceptWith(interceptor!),
  );

  /// Folders the fake picker returns, in order; empty means cancelled.
  final picks = <String>[];
  final FakeTagReader reader;
  final backend = FakeAudioBackend();
  late final Directory tmp = Directory.systemTemp.createTempSync('library_ui');
  late final ProviderContainer container;

  /// Folder pickers and root additions started and not finished yet.
  int pendingPicks = 0;
  int pendingAddRoots = 0;

  /// A real, canonical folder named [name] under the temp directory.
  String folder(String name) {
    final dir = Directory('${tmp.resolveSymbolicLinksSync()}/$name')
      ..createSync(recursive: true);
    return dir.path;
  }

  void touch(String folderPath, String name) =>
      File('$folderPath/$name').writeAsStringSync('x');

  Future<void> pump(WidgetTester tester, {bool hasRoots = false}) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        ...LibraryStartup(
          db: hasDatabase ? db : null,
          hasRoots: hasRoots,
          coverCacheDirectory: coverCacheDirectory,
        ).overrides,
        tagReaderProvider.overrideWithValue(reader),
        audioBackendProvider.overrideWithValue(backend),
        directoryPickerProvider.overrideWithValue(() async {
          pendingPicks++;
          try {
            return await (picker ??
                () async => picks.isEmpty ? null : picks.removeAt(0))();
          } finally {
            pendingPicks--;
          }
        }),
        libraryRootsControllerProvider.overrideWith(
          (ref) => rootsController ?? _CountingRootsController(ref, this),
        ),
        suggestedMusicFolderProvider.overrideWith((ref) => suggestion),
        libraryBrowseRefreshIntervalProvider.overrideWithValue(refreshInterval),
        rootIsDirectoryProvider.overrideWithValue(
          rootIsDirectory ?? (_) async => true,
        ),
        ...overrides,
      ],
    );
    addTearDown(() async {
      container.dispose();
      await tester.runAsync(() async {
        await db.close();
        tmp.deleteSync(recursive: true);
      });
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KanaruApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Counts the root additions in flight on [harness].
class _CountingRootsController extends LibraryRootsController {
  _CountingRootsController(super.ref, this.harness);

  final LibraryHarness harness;

  @override
  Future<AddRootsResult> addRoots(List<String> paths) async {
    harness.pendingAddRoots++;
    try {
      return await super.addRoots(paths);
    } finally {
      harness.pendingAddRoots--;
    }
  }
}

/// What [settleIo] still waits for, or null when everything is quiet.
String? _busyWith(LibraryHarness h) {
  if (h.pendingPicks > 0) return 'a folder picker';
  if (h.pendingAddRoots > 0) return 'adding folders';
  if (h.container.read(libraryIndexerProvider) is IndexerScanning) {
    return 'the indexer scan';
  }
  final keys = h.container.read(libraryKeysProvider).phase;
  if (keys != KeysPhase.ready) return 'the library keys (${keys.name})';
  return null;
}

/// Lets real I/O (directory checks, the walk isolate) finish, then settles
/// the UI. The widget tester's clock does not run file system futures, and
/// each step of a chain (pick, check, store, scan) starts only after the
/// previous one was pumped, so alternate pumping and short real waits until
/// nothing is in flight (picker, adding folders, scan, key backfill) on two
/// checks in a row: the next step of a chain is not visible until the pump
/// after the previous one. Fails after [timeout] naming what is still busy.
/// [eachRound] runs after every pump, for checks on the states in between.
Future<void> settleIo(
  WidgetTester tester,
  LibraryHarness h, {
  Duration timeout = const Duration(seconds: 10),
  void Function(int round)? eachRound,
}) async {
  final watch = Stopwatch()..start();
  var quiet = 0;
  for (var round = 0; quiet < 2; round++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    eachRound?.call(round);
    final busy = _busyWith(h);
    if (busy == null) {
      quiet++;
    } else {
      quiet = 0;
      if (watch.elapsed > timeout) {
        fail('settleIo: still waiting for $busy after $timeout');
      }
    }
  }
  await tester.pumpAndSettle();
}

/// Pumps and waits in real time until a scan is reading tags (a gated tag
/// reader then holds it there). Fails after [timeout].
Future<void> waitForScanReading(
  WidgetTester tester,
  LibraryHarness h, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final watch = Stopwatch()..start();
  while (true) {
    await tester.pump();
    final state = h.container.read(libraryIndexerProvider);
    if (state is IndexerScanning && state.phase == ScanPhase.reading) break;
    if (watch.elapsed > timeout) {
      fail(
        'waitForScanReading: no scan was reading tags after $timeout '
        '(state: ${state.runtimeType})',
      );
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pump();
}
