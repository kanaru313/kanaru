import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/home/home_providers.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/library_browse_refresh.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

/// A page under test inside the real localizations, a memory database, a
/// fixed clock and a fake audio backend, without the rest of the app.
class HomeHarness {
  HomeHarness({DateTime? now, this.hasDatabase = true})
    : now = now ?? DateTime(2026, 10, 24, 12);

  final DateTime now;
  final bool hasDatabase;
  final backend = FakeAudioBackend();
  late final LibraryDatabase db = LibraryDatabase(NativeDatabase.memory());
  late ProviderContainer container;
  int _rootId = 0;

  /// Stores a track; the first call also stores the library root.
  Future<void> addTrack(
    String path, {
    String? artist,
    String? album,
    int? addedAt,
  }) async {
    if (_rootId == 0) {
      await db.addRoots(['/m'], now: 1);
      _rootId = (await db.select(db.libraryRoots).getSingle()).id;
    }
    await db.upsertTracks([
      TracksCompanion.insert(
        rootId: _rootId,
        path: path,
        mtimeMs: 1,
        sizeBytes: 1,
        title: 'T $path',
        artist: Value(artist),
        album: Value(album),
        addedAt: addedAt ?? now.millisecondsSinceEpoch,
        updatedAt: 1,
      ),
    ]);
  }

  /// Shows [child] in a [width] by 900 window at [textScale], then settles.
  /// A router hosts it so `context.go` works; any other route shows its
  /// path as text.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double width = 1280,
    double height = 900,
    double textScale = 1,
    bool disableAnimations = false,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The scope owns its container, so unmounting the page disposes it and
    // cancels the provider timers before the test checks for pending ones.
    final overridesAll = [
      libraryDatabaseProvider.overrideWithValue(hasDatabase ? db : null),
      audioBackendProvider.overrideWithValue(backend),
      libraryBrowseRefreshIntervalProvider.overrideWithValue(Duration.zero),
      homeClockProvider.overrideWithValue(() => now),
      ...overrides,
    ];
    addTearDown(() => tester.runAsync(db.close));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: child),
        ),
        GoRoute(
          path: '/:rest(.*)',
          builder: (_, state) => Text('at ${state.uri.path}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesAll,
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await tester.pumpAndSettle();
  }
}
