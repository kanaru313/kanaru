import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime_provider.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_http.dart';

import '../store/store_test_env.dart' show FakeRuntime;
import 'repo_controller_env.dart';

/// Waits until the store input has answered (its streams are asynchronous).
Future<PluginStoreInput> loaded(ProviderContainer container) async {
  final sub = container.listen(pluginStoreRawInputProvider, (_, _) {});
  addTearDown(sub.close);
  for (var i = 0; i < 200 && sub.read().isLoading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  return sub.read().requireValue;
}

void main() {
  test('without a library there is no controller and no plugins', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(lyricsPluginReposControllerProvider), isNull);

    final input = await loaded(container);
    expect(input.records, isEmpty);
    expect(input.repos, isEmpty);
    // Empty because nothing can be read, not because there is nothing.
    expect(input.available, isFalse);
    final view = buildPluginStoreView(input);
    expect(view.isEmpty, isTrue);
    expect(view.available, isFalse);
  });

  test('with a library the repos and records flow into the store', () async {
    final env = await RepoEnv.create();
    addTearDown(env.dispose);
    env.serveCatalog([entryJson()]);
    env.routes['/demo.zip'] = pluginZip();
    final container = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(env.store.db),
        pluginRuntimeProvider.overrideWithValue(FakeRuntime()),
        lyricsPluginsControllerProvider.overrideWithValue(env.store.controller),
        repoHttpProvider.overrideWithValue(
          RepoHttp(resolver: env.resolver.call, dialer: env.dialer.call),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(lyricsPluginReposControllerProvider)!;
    expect(await controller.add(catalogUrl), isA<AddRepoAdded>());

    final input = await loaded(container);
    expect(input.available, isTrue);
    expect(input.repos.single.name, 'Official');
    final view = buildPluginStoreView(input);
    expect(view.available, isTrue);
    expect(view.notInstalled.single.name, 'Demo');

    expect(await controller.install(catalogUrl, 'demo'), isA<RepoPluginDone>());
    // Let both streams deliver the new record.
    for (var i = 0; i < 200; i++) {
      final now = container.read(pluginStoreRawInputProvider).value;
      if (now != null && now.records.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    final after = buildPluginStoreView(await loaded(container));
    expect(after.installed.single.name, 'Demo');
    expect(after.notInstalled, isEmpty);
  });
}
