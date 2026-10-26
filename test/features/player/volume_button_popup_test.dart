import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/player/volume_button.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

void main() {
  Future<TestGesture> pump(
    WidgetTester tester, {
    required bool popupBelow,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(child: VolumeButton(popupBelow: popupBelow)),
        ),
      ),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(VolumeButton)));
    await tester.pump();
    return gesture;
  }

  testWidgets('the popup opens above the button by default', (tester) async {
    await pump(tester, popupBelow: false);

    final button = tester.getRect(find.byType(VolumeButton));
    final popup = tester.getRect(find.byType(Slider));
    expect(popup.bottom, lessThanOrEqualTo(button.top));
  });

  testWidgets('the popup opens below the button when asked', (tester) async {
    await pump(tester, popupBelow: true);

    final button = tester.getRect(find.byType(VolumeButton));
    final popup = tester.getRect(find.byType(Slider));
    expect(popup.top, greaterThanOrEqualTo(button.bottom));
  });

  testWidgets('moving from the button down into the popup keeps it open', (
    tester,
  ) async {
    final gesture = await pump(tester, popupBelow: true);

    await gesture.moveTo(tester.getCenter(find.byType(Slider)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Slider), findsOneWidget);
  });
}
