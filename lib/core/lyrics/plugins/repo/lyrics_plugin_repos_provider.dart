import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/library_startup.dart';
import '../../../plugin_runtime/plugin_runtime_provider.dart';
import '../lyrics_plugins_provider.dart';
import '../lyrics_sources_provider.dart';
import '../package/plugin_package_reader.dart';
import '../store/plugin_file_reader.dart';
import 'lyrics_plugin_repos_controller.dart';
import 'plugin_store_view.dart';
import 'repo_http.dart';
import 'repo_icon_cache.dart';

export 'lyrics_plugin_repos_controller.dart';
export 'plugin_store_view.dart';
export 'repo_icon_cache.dart';

/// The one client of the repository feature (a fresh connection per fetch).
final repoHttpProvider = Provider<RepoHttp>((ref) => RepoHttp());

/// The controller; null while the plugins controller is, so while the
/// library database or the data folder is unavailable.
final lyricsPluginReposControllerProvider =
    Provider<LyricsPluginReposController?>((ref) {
      final plugins = ref.watch(lyricsPluginsControllerProvider);
      final db = ref.watch(libraryDatabaseProvider);
      if (plugins == null || db == null) return null;
      final controller = LyricsPluginReposController(
        db: db,
        plugins: plugins,
        reader: PluginPackageReader(
          TimeLimitedCheckRuntime(ref.watch(pluginRuntimeProvider)),
        ),
        http: ref.watch(repoHttpProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

/// The added repositories with their last catalogs; empty without a
/// controller (watch [lyricsPluginReposControllerProvider] to tell that from
/// no repositories; [pluginStoreRawInputProvider] does, in `available`).
final lyricsPluginReposProvider = StreamProvider<List<PluginRepo>>((ref) {
  final controller = ref.watch(lyricsPluginReposControllerProvider);
  return controller?.watchRepos() ?? Stream.value(const []);
}, retry: (_, _) => null);

/// Records and repositories, both loaded. Loading until both have answered
/// (an empty list would show every plugin as not installed); the UI adds the
/// search text and filter and calls [buildPluginStoreView]. `available` is
/// false without a controller (empty then means "cannot read", not "none").
final pluginStoreRawInputProvider = Provider<AsyncValue<PluginStoreInput>>((
  ref,
) {
  final repos = ref.watch(lyricsPluginReposProvider);
  final available = ref.watch(lyricsPluginReposControllerProvider) != null;
  final sources = ref.watch(lyricsSourcesInputProvider);
  if (repos.hasError) return AsyncError(repos.error!, repos.stackTrace!);
  if (sources.hasError) return AsyncError(sources.error!, sources.stackTrace!);
  final r = repos.value;
  final s = sources.value;
  if (r == null || s == null) return const AsyncLoading();
  return AsyncData(
    PluginStoreInput(records: s.records, repos: r, available: available),
  );
});

/// Catalog icons, in memory (at most 8 MiB).
final repoIconCacheProvider = Provider<RepoIconCache>(
  (ref) => RepoIconCache(ref.watch(repoHttpProvider)),
);
