import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/app/shell/top_bar.dart';
import 'package:kanaru/app/shell/window/desktop_window.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps the real [TopBar] with the custom title bar on. Window calls go to
/// a stub channel and to [toggles], never to the window plugin.
Future<void> pumpTopBar(WidgetTester tester, List<int> toggles) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('window_manager'),
    (call) async => call.method == 'isMaximized' ? false : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      null,
    ),
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/:page',
        pageBuilder: (_, _) => NoTransitionPage(
          child: Scaffold(body: TopBar(onMenuPressed: () {})),
        ),
      ),
    ],
    initialLocation: '/home',
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        routerProvider.overrideWithValue(router),
        customTitleBarProvider.overrideWithValue(true),
        toggleMaximizeProvider.overrideWithValue(
          () async => toggles.add(toggles.length),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> doubleClickAt(WidgetTester tester, Offset at) async {
  for (var i = 0; i < 2; i++) {
    final gesture = await tester.startGesture(
      at,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  testWidgets('double clicking any control in the top bar does not maximize', (
    tester,
  ) async {
    final toggles = <int>[];
    await pumpTopBar(tester, toggles);

    final buttons = find.byType(IconButton).evaluate().length;
    // Menu, back, forward, open music, settings, minimize, maximize, close.
    expect(buttons, 8);
    for (var i = 0; i < buttons; i++) {
      // Close is last; the stub channel swallows the window calls.
      await doubleClickAt(
        tester,
        tester.getCenter(find.byType(IconButton).at(i)),
      );
      await tester.pumpAndSettle();
    }
    await doubleClickAt(tester, tester.getCenter(find.byType(SearchBar)));

    expect(toggles, isEmpty);
  });

  testWidgets('double clicking empty space in the top bar maximizes', (
    tester,
  ) async {
    final toggles = <int>[];
    await pumpTopBar(tester, toggles);

    // Between the search field (at most 320 wide) and the right-hand buttons.
    final bar = tester.getRect(find.byType(TopBar));
    await doubleClickAt(tester, Offset(bar.center.dx + 100, bar.center.dy));

    expect(toggles, hasLength(1));
  });
}
