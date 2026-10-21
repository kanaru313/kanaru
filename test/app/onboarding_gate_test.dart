import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/library/onboarding/onboarding_screen.dart';

import '../features/library/library_test_harness.dart';

void main() {
  const onboarded = AppSettings(libraryOnboarded: true);

  testWidgets('a first run with no folder shows the source picker', (
    tester,
  ) async {
    await LibraryHarness(suggestion: '/music').pump(tester);

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('an onboarded app with no folder opens the empty library', (
    tester,
  ) async {
    final h = LibraryHarness(
      overrides: [initialSettingsProvider.overrideWithValue(onboarded)],
    );
    await h.pump(tester);

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Your library is empty'), findsOneWidget);
  });

  testWidgets('an app with folders skips the picker even without the flag', (
    tester,
  ) async {
    await LibraryHarness().pump(tester, hasRoots: true);

    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('Later marks the app onboarded for the next launch', (
    tester,
  ) async {
    final h = LibraryHarness(suggestion: '/music');
    await h.pump(tester);
    expect(h.container.read(settingsProvider).libraryOnboarded, isFalse);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(h.container.read(settingsProvider).libraryOnboarded, isTrue);
  });
}
