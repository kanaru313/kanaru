import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:material_ui/material_ui.dart';

import '../core/player/fake_audio_backend.dart';

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
      child: const KanaruApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('collapsed sidebar shows tooltips right of the icons', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(1280, 800));
    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();

    final item = tester.getRect(find.byTooltip('Albums'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: item.center);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The tooltip bubble, not the item it describes.
    final bubble = tester.getRect(find.text('Albums').last);
    expect(bubble.left, greaterThan(item.right));
    expect(bubble.center.dy, closeTo(item.center.dy, 1));
  });

  testWidgets('narrow top bar gives back/forward space to the search field', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(480, 800));

    expect(find.byTooltip('Back'), findsNothing);
    expect(find.byTooltip('Forward'), findsNothing);
    final menu = tester.getRect(
      find.ancestor(
        of: find.byIcon(Icons.menu),
        matching: find.byType(IconButton),
      ),
    );
    expect(tester.getRect(find.byType(SearchBar)).left, menu.right + 8);
  });

  testWidgets('wide top bar keeps back/forward', (tester) async {
    await _pumpApp(tester, const Size(1280, 800));

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('Forward'), findsOneWidget);
  });
}
