import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../core/lyrics/online/lookup_test_harness.dart';

/// The lyrics settings rows over an in-memory library and a fake lyrics
/// provider, in a wide window.
class LyricsRowsHarness {
  LyricsRowsHarness._(this.h, this.visible);

  final LyricsHarness h;

  /// Whether the row is in the tree; the app around it stays, as in the app.
  final ValueNotifier<bool> visible;

  ProviderContainer get container => h.container;
  LyricsProviderRegistration get registration => h.registrations.single;

  static Future<LyricsRowsHarness> create(
    WidgetTester tester,
    Widget child, {
    bool autoFetch = false,
    bool autoConsent = false,
    bool manualConsent = false,
    bool withDatabase = true,
    List<FakeLyricsProvider> extraProviders = const [],
    LibraryDatabase? database,
  }) async {
    final h = await createHarness(
      [
        for (final p in [FakeLyricsProvider(), ...extraProviders])
          LyricsProviderRegistration(p),
      ],
      autoFetch: autoFetch,
      autoConsent: autoConsent,
      manualConsent: manualConsent,
      withDatabase: withDatabase,
      database: database,
    );
    final visible = ValueNotifier(true);
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
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, show, _) =>
                  show ? SingleChildScrollView(child: child) : const SizedBox(),
            ),
          ),
        ),
      ),
    );
    return LyricsRowsHarness._(h, visible);
  }
}
