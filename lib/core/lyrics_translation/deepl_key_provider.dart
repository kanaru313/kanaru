import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../secrets/secret_store_provider.dart';
import 'deepl_api.dart';
import 'deepl_translator.dart';
import 'deepl_usage.dart';
import 'lyrics_translator.dart';
import 'translation_jobs.dart';
import 'translation_providers.dart';
import 'translation_service.dart';

/// Where DeepL is called; `null` picks the host the key belongs to. Tests
/// point it at a loopback server.
final deeplBaseUriProvider = Provider<Uri?>((ref) => null);

/// The stored DeepL key, `null` when there is none. Built on first watch (the
/// secret store is not touched before the DeepL service is in use) and never
/// retried: a failed read stays failed until the settings row asks again.
class DeepLKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final store = await ref.watch(secretStoreProvider.future);
    final key = await store.read(deeplApiKeySecret);
    return key == null || key.trim().isEmpty ? null : key;
  }

  /// Checks [raw] against DeepL's usage endpoint and stores it only when
  /// DeepL accepted it. Throws `TranslationException` (`badKey`, `network`,
  /// ...) or `SecretStoreException`; nothing is stored then. Also throws a
  /// `StateError`, before anything is stored, when the provider was disposed
  /// while DeepL answered. Once the key is written the call succeeds even if
  /// the provider went away meanwhile.
  Future<DeepLUsage> save(String raw) async {
    final key = normalizeDeepLKey(raw);
    final usage = await fetchDeepLUsage(
      ref.read(translationHttpClientProvider),
      key,
      baseUri: ref.read(deeplBaseUriProvider),
    );
    if (!ref.mounted) throw StateError('key provider disposed');
    final store = await ref.read(secretStoreProvider.future);
    await store.write(deeplApiKeySecret, key);
    if (ref.mounted) {
      state = AsyncData(key);
      _forgetFailures();
    }
    return usage;
  }

  /// A new or removed key makes remembered DeepL failures obsolete.
  void _forgetFailures() => ref
      .read(translationJobsProvider.notifier)
      .clearFailures(LyricsTranslationService.deepl);

  /// Removes the stored key.
  Future<void> clear() async {
    final store = await ref.read(secretStoreProvider.future);
    await store.delete(deeplApiKeySecret);
    if (ref.mounted) {
      state = const AsyncData(null);
      _forgetFailures();
    }
  }
}

final deeplApiKeyProvider = AsyncNotifierProvider<DeepLKeyNotifier, String?>(
  DeepLKeyNotifier.new,
  retry: (_, _) => null,
);

/// The DeepL translator for the stored key; `null` without a key (or while
/// it loads).
final deeplTranslatorProvider = Provider<LyricsTranslator?>((ref) {
  final key = ref.watch(deeplApiKeyProvider).value;
  return key == null
      ? null
      : DeepLTranslator(
          ref.watch(translationHttpClientProvider),
          key,
          baseUri: ref.watch(deeplBaseUriProvider),
        );
});

/// Quota used with the stored key; `null` without a key. The settings
/// refresh icon invalidates it.
final deeplUsageProvider = FutureProvider.autoDispose<DeepLUsage?>((ref) async {
  final key = await ref.watch(deeplApiKeyProvider.future);
  if (key == null) return null;
  return fetchDeepLUsage(
    ref.read(translationHttpClientProvider),
    key,
    baseUri: ref.read(deeplBaseUriProvider),
  );
}, retry: (_, _) => null);
