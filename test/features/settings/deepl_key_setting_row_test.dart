import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/paths/app_directories.dart';
import 'package:kanaru/core/secrets/secret_store.dart';
import 'package:kanaru/features/settings/deepl_key_setting_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics_translation/fake_translator.dart';
import '../../core/lyrics_translation/loopback_server.dart';
import 'translation_settings_harness.dart';

const _otherKey = 'zyxwvutsrqzyxwvutsrqzyxwvutsrq';

/// Refuses every write, as a keyring that stopped answering does.
class _FailingWriteStore extends FakeSecretStore {
  @override
  Future<void> write(String key, String value) =>
      throw const SecretStoreException(SecretStoreFailure.timeout);
}

void main() {
  const row = DeepLKeySettingRow();

  Future<void> enterKey(WidgetTester tester, String key) async {
    await tester.enterText(find.byType(TextField), key);
    await tester.pump();
  }

  Future<void> saveKey(WidgetTester tester, String key) async {
    await enterKey(tester, key);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
  }

  Finder button(String label) => find.widgetWithText(FilledButton, label);

  testWidgets('a locked keyring says so and Retry asks again', (tester) async {
    final store = FakeSecretStore()
      ..readError = const SecretStoreException(SecretStoreFailure.locked);
    final h = TranslationSettingsHarness(store: store);
    await h.pump(tester, row);

    expect(
      find.text('Keyring is locked; unlock it, then retry'),
      findsOneWidget,
    );
    expect(h.server.requests, isEmpty);

    store.readError = null;
    await tester.tap(find.text('Retry'));
    await pumpIo(tester);
    expect(button('Add key'), findsOneWidget);
  });

  testWidgets('no default keyring and a silent keyring have their own text', (
    tester,
  ) async {
    final store = FakeSecretStore()
      ..readError = const SecretStoreException(
        SecretStoreFailure.noDefaultCollection,
      );
    final h = TranslationSettingsHarness(store: store);
    await h.pump(tester, row);
    expect(find.textContaining('create one'), findsOneWidget);
    expect(find.textContaining('Seahorse or KWallet'), findsOneWidget);

    store.readError = const SecretStoreException(SecretStoreFailure.timeout);
    await tester.tap(find.text('Retry'));
    await pumpIo(tester);
    expect(find.text('The keyring is not responding'), findsOneWidget);
  });

  testWidgets('adding a key checks it, stores it and shows only a mask', (
    tester,
  ) async {
    final h = TranslationSettingsHarness();
    await h.pump(tester, row);
    await tester.tap(button('Add key'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );

    await saveKey(tester, deeplTestKey);
    await pumpIo(tester, done: () => find.byType(TextField).evaluate().isEmpty);

    expect(h.store.values['deepl_api_key'], deeplTestKey);
    expect(h.server.requests.single.uri.path, '/v2/usage');
    expect(find.textContaining('•' * 8), findsOneWidget);
    expect(find.textContaining('Free'), findsOneWidget);
    expect(
      find.textContaining('Used 12,345 of 500,000 characters'),
      findsOneWidget,
    );
    expect(find.byTooltip('Refresh usage'), findsOneWidget);
    expect(button('Edit'), findsOneWidget);
    expect(button('Clear'), findsOneWidget);
    // The key is nowhere on screen or in an input.
    expect(find.textContaining(deeplTestKey), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a key DeepL refuses keeps the dialog open and stores nothing', (
    tester,
  ) async {
    final h = TranslationSettingsHarness()..usage = const Reply(403, '');
    await h.pump(tester, row);
    await tester.tap(button('Add key'));
    await tester.pumpAndSettle();

    await saveKey(tester, deeplTestKey);
    await pumpIo(
      tester,
      done: () => find.textContaining('did not accept').evaluate().isNotEmpty,
    );

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(h.store.values, isEmpty);
    expect(h.store.writes, 0);
    // Saving can be tried again.
    expect(tester.widget<FilledButton>(button('Save')).onPressed, isNotNull);
  });

  testWidgets('without a network the reason shows and nothing is stored', (
    tester,
  ) async {
    final h = TranslationSettingsHarness();
    await h.pump(tester, row);
    await tester.runAsync(h.server.close);
    await tester.tap(button('Add key'));
    await tester.pumpAndSettle();

    await saveKey(tester, deeplTestKey);
    await pumpIo(
      tester,
      done: () => find.textContaining('Could not reach').evaluate().isNotEmpty,
    );

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(h.store.values, isEmpty);
  });

  testWidgets('a keyring that fails to write is reported, nothing is kept', (
    tester,
  ) async {
    final store = _FailingWriteStore();
    final h = TranslationSettingsHarness(store: store);
    await h.pump(tester, row);
    await tester.tap(button('Add key'));
    await tester.pumpAndSettle();

    await saveKey(tester, deeplTestKey);
    await pumpIo(
      tester,
      done: () =>
          find.text('The keyring is not responding').evaluate().isNotEmpty,
    );

    expect(store.values, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Edit replaces the stored key', (tester) async {
    final store = FakeSecretStore()..values['deepl_api_key'] = deeplTestKey;
    final h = TranslationSettingsHarness(store: store);
    await h.pump(tester, row);

    await tester.tap(button('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Replace DeepL API key'), findsOneWidget);
    await saveKey(tester, _otherKey);
    await pumpIo(tester, done: () => find.byType(TextField).evaluate().isEmpty);

    expect(store.values['deepl_api_key'], _otherKey);
    // A key without `:fx` is a paid one.
    expect(find.textContaining('Pro'), findsOneWidget);
  });

  testWidgets('Clear removes the key after a confirmation only', (
    tester,
  ) async {
    final store = FakeSecretStore()..values['deepl_api_key'] = deeplTestKey;
    final h = TranslationSettingsHarness(store: store);
    await h.pump(tester, row);

    await tester.tap(button('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await pumpIo(tester);
    expect(store.values, isNotEmpty);

    await tester.tap(button('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Clear'),
      ),
    );
    await pumpIo(tester, done: () => button('Add key').evaluate().isNotEmpty);

    expect(store.values, isEmpty);
    expect(h.server.requests, isEmpty);
  });

  testWidgets('the usage is read only when the refresh icon is pressed', (
    tester,
  ) async {
    final store = FakeSecretStore()..values['deepl_api_key'] = deeplTestKey;
    final h = TranslationSettingsHarness(store: store);
    await h.pump(tester, row);
    expect(h.server.requests, isEmpty);
    expect(find.textContaining('Used '), findsNothing);

    await tester.tap(find.byTooltip('Refresh usage'));
    await pumpIo(
      tester,
      done: () => find.textContaining('Used 12,345').evaluate().isNotEmpty,
    );

    expect(h.server.requests, hasLength(1));
    expect(find.textContaining(deeplTestKey), findsNothing);
  });

  testWidgets('a key without :fx is a Pro key', (tester) async {
    final store = FakeSecretStore()..values['deepl_api_key'] = _otherKey;
    final h = TranslationSettingsHarness(store: store);
    await h.pump(tester, row);

    expect(find.textContaining('Pro'), findsOneWidget);
    expect(find.textContaining('Free'), findsNothing);
  });

  testWidgets('a plan without a limit reads "Used N characters"', (
    tester,
  ) async {
    final store = FakeSecretStore()..values['deepl_api_key'] = _otherKey;
    final h = TranslationSettingsHarness(store: store)
      ..usage = const Reply(
        200,
        '{"character_count":12345,"character_limit":1000000000000}',
      );
    await h.pump(tester, row);

    await tester.tap(find.byTooltip('Refresh usage'));
    await pumpIo(
      tester,
      done: () => find.textContaining('Used 12,345').evaluate().isNotEmpty,
    );
    expect(find.textContaining('Used 12,345 characters'), findsOneWidget);
    expect(find.textContaining(' of '), findsNothing);
  });

  group('where the key is kept', () {
    testWidgets('a system keyring shows no warning', (tester) async {
      final h = TranslationSettingsHarness();
      await h.pump(tester, row);
      expect(find.textContaining('No system keyring'), findsNothing);
    });

    testWidgets('a key file shows the warning with the real path', (
      tester,
    ) async {
      final h = TranslationSettingsHarness(usingFallback: true);
      await h.pump(tester, row);

      expect(find.textContaining('No system keyring found'), findsOneWidget);
      final dataDir = resolveDataDirectory(Platform.environment);
      if (dataDir != null) {
        expect(find.textContaining('$dataDir/secrets.json'), findsOneWidget);
      }
      expect(find.textContaining('secrets.json'), findsOneWidget);
      expect(find.textContaining('Do not share or sync'), findsOneWidget);
      expect(find.textContaining('permissions were fixed'), findsNothing);
    });

    testWidgets('a tightened file adds its own line', (tester) async {
      final h = TranslationSettingsHarness(
        usingFallback: true,
        modeWasFixed: true,
      );
      await h.pump(tester, row);
      expect(find.textContaining('permissions were fixed'), findsOneWidget);
    });

    testWidgets('a memory-only store says the key goes at exit', (
      tester,
    ) async {
      final h = TranslationSettingsHarness(
        usingFallback: true,
        persistent: false,
      );
      await h.pump(tester, row);

      expect(find.textContaining('until Kanaru closes'), findsOneWidget);
      expect(find.textContaining('secrets.json'), findsNothing);
    });
  });
}
