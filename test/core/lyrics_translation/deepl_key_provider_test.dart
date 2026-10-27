import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/deepl_key_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/secrets/secret_store_provider.dart';

import 'fake_translator.dart';
import 'loopback_server.dart';

const _key = 'abcdefghijabcdefghijabcdefghij:fx';
const _usage = Reply(200, '{"character_count":5,"character_limit":500000}');

void main() {
  late FakeSecretStore store;
  late LoopbackServer server;

  setUp(() async {
    store = FakeSecretStore();
    server = await LoopbackServer.start((_) => _usage);
  });
  tearDown(() => server.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        deeplBaseUriProvider.overrideWithValue(server.baseUri),
        secretStoreProvider.overrideWith(
          (ref) async => ResolvedSecretStore(
            store,
            usingFallback: false,
            persistent: false,
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the store is not touched until the key is watched', () async {
    final c = container();
    await settle();
    expect(store.reads, 0);

    c.listen(deeplApiKeyProvider, (_, _) {});
    await c.read(deeplApiKeyProvider.future);
    expect(store.reads, 1);
  });

  test('reads the stored key; blank counts as none', () async {
    store.values['deepl_api_key'] = _key;
    expect(await container().read(deeplApiKeyProvider.future), _key);

    store.values['deepl_api_key'] = '   ';
    expect(await container().read(deeplApiKeyProvider.future), isNull);
  });

  test('save with a key DeepL refuses: badKey, nothing stored', () async {
    server.handler = (_) => const Reply(403, '');
    final c = container();
    c.listen(deeplApiKeyProvider, (_, _) {});
    await c.read(deeplApiKeyProvider.future);

    await expectLater(
      c.read(deeplApiKeyProvider.notifier).save(_key),
      throwsA(
        isA<TranslationException>().having(
          (e) => e.kind,
          'kind',
          TranslationFailureKind.badKey,
        ),
      ),
    );
    expect(store.values, isEmpty);
    expect(store.writes, 0);
    expect(c.read(deeplApiKeyProvider).value, isNull);
  });

  test('save with a key that cannot be one sends nothing', () async {
    final c = container();
    await expectLater(
      c.read(deeplApiKeyProvider.notifier).save('too short'),
      throwsA(isA<TranslationException>()),
    );
    expect(server.requests, isEmpty);
    expect(store.writes, 0);
  });

  test('save stores the trimmed key after DeepL accepted it', () async {
    final c = container();
    c.listen(deeplApiKeyProvider, (_, _) {});
    await c.read(deeplApiKeyProvider.future);

    final usage = await c.read(deeplApiKeyProvider.notifier).save('  $_key \n');
    expect(usage.characterCount, 5);
    expect(usage.characterLimit, 500000);
    expect(usage.freeKey, isTrue);
    expect(store.values['deepl_api_key'], _key);
    expect(c.read(deeplApiKeyProvider).value, _key);
    expect(server.requests.single.uri.path, '/v2/usage');
    expect(c.read(deeplTranslatorProvider), isNotNull);
  });

  test('clear removes the key and the translator', () async {
    store.values['deepl_api_key'] = _key;
    final c = container();
    c.listen(deeplApiKeyProvider, (_, _) {});
    await c.read(deeplApiKeyProvider.future);
    expect(c.read(deeplTranslatorProvider), isNotNull);

    await c.read(deeplApiKeyProvider.notifier).clear();
    expect(store.values, isEmpty);
    expect(c.read(deeplApiKeyProvider).value, isNull);
    expect(c.read(deeplTranslatorProvider), isNull);
  });

  test('a failed read is not retried by the provider', () async {
    store.readError = const SecretStoreException(SecretStoreFailure.locked);
    final c = container();
    c.listen(deeplApiKeyProvider, (_, _) {});
    await expectLater(
      c.read(deeplApiKeyProvider.future),
      throwsA(isA<SecretStoreException>()),
    );
    await settle(const Duration(seconds: 2));
    expect(store.reads, 1);
  });

  test('usage: none without a key, the quota with one', () async {
    final c = container();
    c.listen(deeplUsageProvider, (_, _) {});
    expect(await c.read(deeplUsageProvider.future), isNull);

    store.values['deepl_api_key'] = _key;
    c.invalidate(deeplApiKeyProvider);
    c.invalidate(deeplUsageProvider);
    final usage = await c.read(deeplUsageProvider.future);
    expect(usage!.characterLimit, 500000);
    expect(server.requests, hasLength(1));
  });

  test('a container disposed during the write still stores the key', () async {
    final c = container();
    c.listen(deeplApiKeyProvider, (_, _) {});
    await c.read(deeplApiKeyProvider.future);
    store.writeGate = Completer<void>();

    final saving = c.read(deeplApiKeyProvider.notifier).save(_key);
    await until(() => store.writes == 1);
    c.dispose();
    store.writeGate!.complete();

    expect((await saving).characterLimit, 500000);
    expect(store.values['deepl_api_key'], _key);
  });
}
