import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show MaterialApp, Size, Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/app/shell/navigation_history.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/library_browse_refresh.dart';

import '../core/player/fake_audio_backend.dart';

/// Mounts a minimal router (one route per path, `/x` optionally redirecting
/// to `/b`) and returns its container. Much faster than the whole app.
Future<ProviderContainer> pumpRouter(
  WidgetTester tester, {
  String initialLocation = '/home',
  bool Function()? redirectXToB,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/:page',
        redirect: (_, state) =>
            state.uri.path == '/x' && (redirectXToB?.call() ?? false)
            ? '/b'
            : null,
        builder: (_, state) => Text(state.uri.toString()),
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [routerProvider.overrideWithValue(router)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  // The history only records locations once something reads it.
  container.read(navigationHistoryProvider);
  return container;
}

/// Mounts the whole app so the real router and its redirects are attached.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  LibraryDatabase? db,
  bool hasRoots = true,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      libraryDatabaseProvider.overrideWithValue(db),
      libraryHasRootsProvider.overrideWith(() => LibraryHasRoots(hasRoots)),
      // Reload browse lists at once so no refresh timer outlives the test.
      libraryBrowseRefreshIntervalProvider.overrideWithValue(Duration.zero),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KanaruApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('starts on the initial location', (tester) async {
    final container = await pumpRouter(tester);
    final history = container.read(navigationHistoryProvider);

    expect(history.entries, ['/home']);
    expect(history.canGoBack, isFalse);
    expect(history.canGoForward, isFalse);
  });

  testWidgets('keeps at most 100 entries and drops the oldest', (tester) async {
    final container = await pumpRouter(tester);
    final router = container.read(routerProvider);

    for (var i = 0; i < 150; i++) {
      router.go('/search?q=$i');
      await tester.pump();
    }
    final history = container.read(navigationHistoryProvider);

    expect(history.entries, hasLength(100));
    expect(history.entries.last, '/search?q=149');
    expect(history.entries.first, '/search?q=50');
    expect(history.index, 99);
  });

  testWidgets('trimming leaves the previous state untouched', (tester) async {
    final container = await pumpRouter(tester);
    final router = container.read(routerProvider);
    for (var i = 0; i < 99; i++) {
      router.go('/search?q=$i');
      await tester.pump();
    }
    final before = container.read(navigationHistoryProvider);
    final snapshot = List.of(before.entries);
    expect(snapshot, hasLength(100));

    router.go('/settings');
    await tester.pump();

    expect(before.entries, snapshot);
    final after = container.read(navigationHistoryProvider);
    expect(after.entries, hasLength(100));
    expect(after.entries.last, '/settings');
  });

  testWidgets('back and forward still work after the cap', (tester) async {
    final container = await pumpRouter(tester);
    final router = container.read(routerProvider);
    final notifier = container.read(navigationHistoryProvider.notifier);
    for (var i = 0; i < 120; i++) {
      router.go('/search?q=$i');
      await tester.pump();
    }

    notifier.back();
    await tester.pump();
    var history = container.read(navigationHistoryProvider);
    expect(history.index, 98);
    expect(history.entries[98], '/search?q=118');
    expect(history.canGoForward, isTrue);

    notifier.forward();
    await tester.pump();
    history = container.read(navigationHistoryProvider);
    expect(history.index, 99);
    expect(history.entries.last, '/search?q=119');
    expect(history.canGoForward, isFalse);
  });

  testWidgets('a visit after going back onto a redirect to the current page '
      'is appended', (tester) async {
    var redirect = false;
    final container = await pumpRouter(
      tester,
      initialLocation: '/x',
      redirectXToB: () => redirect,
    );
    final router = container.read(routerProvider);
    final notifier = container.read(navigationHistoryProvider.notifier);
    router.go('/b');
    await tester.pump();
    expect(container.read(navigationHistoryProvider).entries, ['/x', '/b']);

    // /x now redirects to /b, where the router already is: nobody is told.
    redirect = true;
    notifier.back();
    await tester.pump();
    router.go('/c');
    await tester.pump();

    final history = container.read(navigationHistoryProvider);
    expect(history.entries.last, '/c');
    expect(history.index, history.entries.length - 1);
    expect(history.canGoForward, isFalse);
  });

  testWidgets('stores the location a redirect lands on', (tester) async {
    // First run: a database without roots opens on /welcome.
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await pumpApp(tester, db: db, hasRoots: false);
    final router = container.read(routerProvider);
    final notifier = container.read(navigationHistoryProvider.notifier);
    expect(container.read(navigationHistoryProvider).entries, ['/welcome']);

    container.read(libraryHasRootsProvider.notifier).markPresent();
    router.go('/songs');
    await tester.pump();
    router.go('/settings');
    await tester.pump();
    notifier.back();
    await tester.pump();
    notifier.back();
    await tester.pump();
    var history = container.read(navigationHistoryProvider);

    // /welcome now redirects to /home; the forward stack must survive.
    expect(history.entries, ['/home', '/songs', '/settings']);
    expect(history.index, 0);
    expect(history.canGoForward, isTrue);

    notifier.forward();
    await tester.pump();
    notifier.forward();
    await tester.pump();
    history = container.read(navigationHistoryProvider);
    expect(history.index, 2);
    expect(history.entries.last, '/settings');
  });

  test('routerProvider disposes its router with the container', () {
    final container = ProviderContainer();
    final router = container.read(routerProvider);

    container.dispose();

    expect(
      () => router.routerDelegate.addListener(() {}),
      throwsA(isA<FlutterError>()),
    );
  });
}
