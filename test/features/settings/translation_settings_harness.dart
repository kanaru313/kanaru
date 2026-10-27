import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/lyrics_translation/deepl_key_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_providers.dart';
import 'package:kanaru/core/secrets/secret_store_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics_translation/fake_translator.dart';
import '../../core/lyrics_translation/loopback_server.dart';

const deeplTestKey = 'abcdefghijabcdefghijabcdefghij:fx';

/// Where the DeepL key and usage calls of the settings rows go: a loopback
/// server, a fake secret store and an in-memory library database. Never the
/// internet, the real keyring or a real key.
class TranslationSettingsHarness {
  TranslationSettingsHarness({
    this.settings = const AppSettings(),
    this.hasDatabase = true,
    this.usingFallback = false,
    this.persistent = true,
    this.modeWasFixed = false,
    FakeSecretStore? store,
  }) : store = store ?? FakeSecretStore();

  final AppSettings settings;
  final bool hasDatabase;
  final bool usingFallback;
  final bool persistent;
  final bool modeWasFixed;
  final FakeSecretStore store;
  final db = LibraryDatabase(NativeDatabase.memory());
  late final LoopbackServer server;
  late final ProviderContainer container;

  /// How DeepL answers `/v2/usage`.
  Reply usage = const Reply(
    200,
    '{"character_count":12345,"character_limit":500000}',
  );

  TranslationPrefs get prefs => container.read(settingsProvider).translation;

  /// Shows [child] in a wide window with the app's localizations.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('en'),
  }) async {
    // flutter_test replaces the HTTP client with one that answers 400.
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previousOverrides);
    server = (await tester.runAsync(() => LoopbackServer.start((_) => usage)))!;
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(settings),
        libraryDatabaseProvider.overrideWithValue(hasDatabase ? db : null),
        deeplBaseUriProvider.overrideWithValue(server.baseUri),
        // An idle connection would keep a timer pending past the test.
        translationHttpClientProvider.overrideWith((ref) {
          final client = HttpClient()..idleTimeout = Duration.zero;
          ref.onDispose(() => client.close(force: true));
          return client;
        }),
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
      await tester.runAsync(() async {
        await server.close();
        await db.close();
      });
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
          home: Scaffold(body: SingleChildScrollView(child: child)),
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
