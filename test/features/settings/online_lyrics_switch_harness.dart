import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../core/lyrics/online/lookup_test_harness.dart';

/// The lyrics settings rows over an in-memory library and a fake lyrics
/// provider, in a wide window.
class LyricsRowsHarness {
  LyricsRowsHarness._(this.h);

  final LyricsHarness h;

  ProviderContainer get container => h.container;
  LyricsProviderRegistration get registration => h.registrations.single;

  static Future<LyricsRowsHarness> create(
    WidgetTester tester,
    Widget child, {
    bool autoFetch = false,
    bool autoConsent = false,
    bool manualConsent = false,
    bool withDatabase = true,
  }) async {
    final h = await createHarness(
      [LyricsProviderRegistration(FakeLyricsProvider())],
      autoFetch: autoFetch,
      autoConsent: autoConsent,
      manualConsent: manualConsent,
      withDatabase: withDatabase,
    );
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    return LyricsRowsHarness._(h);
  }
}
