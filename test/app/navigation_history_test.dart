import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show MaterialApp, Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/app/shell/navigation_history.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';

import 'app_test_harness.dart';

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

void main() {
  testWidgets('starts on the initial location', (tester) async {
    final container = await pumpRouter(tester);
    final history = container.read(navigationHistoryProvider);

    expect(history.entries, ['/home']);
    expect(history.canGoBack, isFalse);
    expect(history.canGoForward, isFalse);
  });

  testWidgets('consecutive search locations replace each other', (
    tester,
  ) async {
    final container = await pumpRouter(tester);
    final router = container.read(routerProvider);

    for (final location in ['/search', '/search?q=a', '/search?q=ab']) {
      router.go(location);
      await tester.pump();
    }

    final history = container.read(navigationHistoryProvider);
    expect(history.entries, ['/home', '/search?q=ab']);
    expect(history.index, 1);
  });

  testWidgets('a search after another page is a new entry and back returns '
      'to that page', (tester) async {
    final container = await pumpRouter(tester);
    final router = container.read(routerProvider);
    final notifier = container.read(navigationHistoryProvider.notifier);

    router.go('/albums');
    await tester.pump();
    router.go('/search?q=son');
    await tester.pump();
    expect(container.read(navigationHistoryProvider).entries, [
      '/home',
      '/albums',
      '/search?q=son',
    ]);

    notifier.back();
    await tester.pump();
    final history = container.read(navigationHistoryProvider);
    expect(history.entries[history.index], '/albums');
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/albums',
    );
  });

  testWidgets('replacing a search drops the forward entries', (tester) async {
    final container = await pumpRouter(tester);
    final router = container.read(routerProvider);
    final notifier = container.read(navigationHistoryProvider.notifier);
    router.go('/search?q=a');
    await tester.pump();
    router.go('/albums');
    await tester.pump();
    notifier.back();
    await tester.pump();
    expect(container.read(navigationHistoryProvider).canGoForward, isTrue);

    router.go('/search?q=ab');
    await tester.pump();

    final history = container.read(navigationHistoryProvider);
    expect(history.entries, ['/home', '/search?q=ab']);
    expect(history.index, 1);
    expect(history.canGoForward, isFalse);
  });

  testWidgets('leaving search and searching again starts a new entry', (
    tester,
  ) async {
    final container = await pumpRouter(tester);
    final router = container.read(routerProvider);

    router.go('/search?q=a');
    await tester.pump();
    router.go('/albums');
    await tester.pump();
    router.go('/search?q=b');
    await tester.pump();

    expect(container.read(navigationHistoryProvider).entries, [
      '/home',
      '/search?q=a',
      '/albums',
      '/search?q=b',
    ]);
  });

  testWidgets('keeps at most 100 entries and drops the oldest', (tester) async {
    final container = await pumpRouter(tester);
    final router = container.read(routerProvider);

    for (var i = 0; i < 150; i++) {
      router.go('/p$i');
      await tester.pump();
    }
    final history = container.read(navigationHistoryProvider);

    expect(history.entries, hasLength(100));
    expect(history.entries.last, '/p149');
    expect(history.entries.first, '/p50');
    expect(history.index, 99);
  });

  testWidgets('trimming leaves the previous state untouched', (tester) async {
    final container = await pumpRouter(tester);
    final router = container.read(routerProvider);
    for (var i = 0; i < 99; i++) {
      router.go('/p$i');
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
      router.go('/p$i');
      await tester.pump();
    }

    notifier.back();
    await tester.pump();
    var history = container.read(navigationHistoryProvider);
    expect(history.index, 98);
    expect(history.entries[98], '/p118');
    expect(history.canGoForward, isTrue);

    notifier.forward();
    await tester.pump();
    history = container.read(navigationHistoryProvider);
    expect(history.index, 99);
    expect(history.entries.last, '/p119');
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
