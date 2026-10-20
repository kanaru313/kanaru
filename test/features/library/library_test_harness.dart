import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/library_sql_functions.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/directory_picker_provider.dart';
import 'package:kanaru/features/library/library_browse_refresh.dart';
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
    this.refreshInterval = Duration.zero,
    this.coverCacheDirectory,
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

  late final LibraryDatabase db = LibraryDatabase(
    NativeDatabase.memory(setup: registerLibrarySqlFunctions),
  );

  /// Folders the fake picker returns, in order; empty means cancelled.
  final picks = <String>[];
  final FakeTagReader reader;
  final backend = FakeAudioBackend();
  late final Directory tmp = Directory.systemTemp.createTempSync('library_ui');
  late final ProviderContainer container;

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
        directoryPickerProvider.overrideWithValue(
          picker ?? () async => picks.isEmpty ? null : picks.removeAt(0),
        ),
        suggestedMusicFolderProvider.overrideWith((ref) => suggestion),
        libraryBrowseRefreshIntervalProvider.overrideWithValue(refreshInterval),
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

/// Lets real I/O (directory checks, the walk isolate) finish, then settles
/// the UI. The widget tester's clock does not run file system futures, and
/// each step of a chain (pick, check, store, scan) starts only after the
/// previous one was pumped, so alternate pumping and real waiting, [rounds]
/// times (more for a longer chain).
Future<void> settleIo(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
  }
  await tester.pumpAndSettle();
}
