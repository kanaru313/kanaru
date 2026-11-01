import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/secrets/secret_store_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics_translation/fake_translator.dart';

/// A fake secret store and an in-memory library database for the translation
/// settings rows. Never the internet, the real keyring or a real key.
class TranslationSettingsHarness {
  TranslationSettingsHarness({
    this.settings = const AppSettings(),
    this.hasDatabase = true,
    this.usingFallback = false,
    this.persistent = true,
    this.modeWasFixed = false,
    FakeSecretStore? store,
    LibraryDatabase? database,
  }) : store = store ?? FakeSecretStore(),
       db = database ?? LibraryDatabase(NativeDatabase.memory());

  final AppSettings settings;
  final bool hasDatabase;
  final bool usingFallback;
  final bool persistent;
  final bool modeWasFixed;
  final FakeSecretStore store;
  final LibraryDatabase db;

  /// Whether the row is in the tree; the app around it stays, as in the app.
  final visible = ValueNotifier(true);
  late final ProviderContainer container;

  TranslationPrefs get prefs => container.read(settingsProvider).translation;

  /// Shows [child] in a wide window with the app's localizations.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(settings),
        libraryDatabaseProvider.overrideWithValue(hasDatabase ? db : null),
        secretStoreProvider.overrideWith(
          (ref) async => ResolvedSecretStore(
            store,
            usingFallback: usingFallback,
            persistent: persistent,
            modeWasFixed: () => modeWasFixed,
          ),
        ),
      ],
    );
    addTearDown(() async {
      tester.view.reset();
      container.dispose();
      await tester.runAsync(db.close);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
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
    await pumpIo(tester);
  }
}

/// Lets real I/O (loopback requests, the database) finish: alternates short
/// real waits with pumps until [done] holds, or [rounds] ran when it is null.
Future<void> pumpIo(
  WidgetTester tester, {
  bool Function()? done,
  int rounds = 10,
}) async {
  for (var i = 0; i < (done == null ? rounds : 200); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 60));
    if (done != null && done()) break;
  }
  if (done != null) expect(done(), isTrue, reason: 'condition not reached');
}
