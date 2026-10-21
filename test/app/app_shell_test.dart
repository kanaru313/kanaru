import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/shell/sidebar/sidebar.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/player/player_bar.dart';
import 'package:material_ui/material_ui.dart';

import '../core/player/fake_audio_backend.dart';

Future<void> pumpApp(
  WidgetTester tester,
  Size size, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
      child: KanaruApp(locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

const wide = Size(1280, 800);
const narrow = Size(480, 800);

void main() {
  testWidgets('opens on the home screen', (tester) async {
    await pumpApp(tester, wide);

    expect(find.text('Your library is empty'), findsOneWidget);
  });

  testWidgets('the top bar has no open-music button, on any width', (
    tester,
  ) async {
    for (final size in [wide, narrow]) {
      await pumpApp(tester, size);

      expect(find.byTooltip('Open music'), findsNothing);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.byType(PlayerBar), findsNothing, reason: 'empty queue');
    }
  });

  testWidgets('shows the sidebar on wide windows', (tester) async {
    await pumpApp(tester, wide);

    expect(find.byType(Sidebar), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsNothing);
  });

  testWidgets('moves the sidebar into a drawer on narrow windows', (
    tester,
  ) async {
    await pumpApp(tester, narrow);
    expect(find.byType(Sidebar), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.byType(Sidebar), findsOneWidget);

    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    expect(find.byType(Sidebar), findsNothing);
    expect(find.text('Albums'), findsOneWidget);
  });

  testWidgets('switches pages from the sidebar', (tester) async {
    await pumpApp(tester, wide);

    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();

    expect(find.text('Songs you like will show up here.'), findsOneWidget);
  });

  testWidgets('back and forward move through visited pages', (tester) async {
    await pumpApp(tester, wide);
    final back = find.byTooltip('Back');
    final forward = find.byTooltip('Forward');

    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('Your library is empty'), findsOneWidget);

    await tester.tap(forward);
    await tester.pumpAndSettle();
    expect(find.text('Artists'), findsNWidgets(2));
  });

  testWidgets('the mouse side buttons move through visited pages', (
    tester,
  ) async {
    await pumpApp(tester, wide);
    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();

    Future<void> press(int button) async {
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: button,
      );
      await mouse.down(const Offset(600, 300));
      await mouse.up();
      await tester.pumpAndSettle();
    }

    bool enabled(String tooltip) =>
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byIcon(
                  tooltip == 'Back' ? Icons.chevron_left : Icons.chevron_right,
                ),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed !=
        null;

    expect(enabled('Back'), isTrue);
    expect(enabled('Forward'), isFalse);
    await press(kBackMouseButton);
    expect(enabled('Back'), isFalse);
    expect(enabled('Forward'), isTrue);
    await press(kForwardMouseButton);
    expect(enabled('Back'), isTrue);
    expect(enabled('Forward'), isFalse);
  });

  testWidgets('back is disabled on the first page', (tester) async {
    await pumpApp(tester, wide);

    final back = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_left),
        matching: find.byType(IconButton),
      ),
    );
    expect(back.onPressed, isNull);
  });

  testWidgets('submitting the search field opens the search page', (
    tester,
  ) async {
    await pumpApp(tester, wide);

    await tester.enterText(find.byType(SearchBar), 'abba');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Results for “abba”'), findsOneWidget);
  });

  testWidgets('settings button opens settings', (tester) async {
    await pumpApp(tester, wide);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets('keeps the top bar buttons at the right edge', (tester) async {
    await pumpApp(tester, wide);

    final settings = tester.getRect(find.byTooltip('Settings'));
    expect(settings.right, closeTo(wide.width - 16, 4));
  });

  testWidgets('sidebar handle collapses the sidebar to icons', (tester) async {
    await pumpApp(tester, wide);

    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();
    expect(find.text('Songs'), findsNothing);
    expect(find.byTooltip('Songs'), findsOneWidget);
    expect(tester.getSize(find.byType(Sidebar)).width, 72);

    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    expect(find.text('Albums'), findsOneWidget);

    await tester.tap(find.byTooltip('Expand sidebar'));
    await tester.pumpAndSettle();
    expect(find.text('Songs'), findsOneWidget);
  });

  testWidgets('hides window buttons without a custom title bar', (
    tester,
  ) async {
    await pumpApp(tester, wide);

    expect(find.byTooltip('Close'), findsNothing);
  });

  testWidgets('renders in Vietnamese', (tester) async {
    await pumpApp(tester, wide, locale: const Locale('vi'));

    expect(find.text('Thư viện của bạn đang trống'), findsOneWidget);
    expect(find.text('Bài hát'), findsOneWidget);
    expect(find.text('Tìm bài hát, album, nghệ sĩ'), findsOneWidget);
  });
}
