import 'package:file_selector/file_selector.dart' as picker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';

/// The search text of the store page. Reset when the page closes.
class PluginStoreSearch extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final pluginStoreSearchProvider =
    NotifierProvider.autoDispose<PluginStoreSearch, String>(
      PluginStoreSearch.new,
    );

/// The source chip chosen on the store page. Reset when the page closes.
class PluginStoreFilter extends Notifier<StoreSourceFilter> {
  @override
  StoreSourceFilter build() => const StoreSourceFilter.all();

  void set(StoreSourceFilter value) => state = value;
}

final pluginStoreFilterProvider =
    NotifierProvider.autoDispose<PluginStoreFilter, StoreSourceFilter>(
      PluginStoreFilter.new,
    );

/// The store list: records and repositories with the search text and the
/// chosen chip applied. A chip whose repository was removed (or whose
/// plugins from files are gone) counts as "all".
final pluginStoreViewProvider =
    Provider.autoDispose<AsyncValue<PluginStoreView>>((ref) {
      final raw = ref.watch(pluginStoreRawInputProvider);
      final search = ref.watch(pluginStoreSearchProvider);
      final chosen = ref.watch(pluginStoreFilterProvider);
      return raw.whenData((input) {
        final known =
            chosen.isAll ||
            (chosen.repoUrl != null &&
                input.repos.any((r) => r.url == chosen.repoUrl)) ||
            (chosen.isFromFile &&
                input.records.any((r) => !r.isRemoved && r.repoUrl == null));
        return buildPluginStoreView(
          PluginStoreInput(
            records: input.records,
            repos: input.repos,
            search: search,
            filter: known ? chosen : const StoreSourceFilter.all(),
            available: input.available,
          ),
        );
      });
    });

/// Install ids being updated right now, for the spinners on the rows.
final pluginStoreUpdatingProvider = StreamProvider.autoDispose<Set<String>>((
  ref,
) async* {
  final controller = ref.watch(lyricsPluginReposControllerProvider);
  if (controller == null) return;
  yield controller.updating;
  yield* controller.updatingChanges;
});

/// Installs started from this screen and not finished, by [pendingInstallKey]:
/// the row shows a spinner and cannot be tapped again.
class PluginStorePendingInstalls extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// False when [key] is already pending.
  bool begin(String key) {
    if (state.contains(key)) return false;
    state = {...state, key};
    return true;
  }

  void end(String key) => state = {...state}..remove(key);
}

final pluginStorePendingInstallsProvider =
    NotifierProvider<PluginStorePendingInstalls, Set<String>>(
      PluginStorePendingInstalls.new,
    );

/// The key of the install of plugin [slug] of the repository [repoUrl].
String pendingInstallKey(String repoUrl, String slug) => '$repoUrl\n$slug';

/// Asks for a plugin zip; the path, or null when cancelled. Tests override it.
typedef PluginZipPicker = Future<String?> Function();

final pluginZipPickerProvider = Provider<PluginZipPicker>(
  (ref) =>
      () async => (await picker.openFile(
        // GTK matches patterns case-sensitively, so both spellings are listed.
        acceptedTypeGroups: const [
          picker.XTypeGroup(
            label: 'zip',
            extensions: ['zip', 'ZIP'],
            mimeTypes: ['application/zip'],
          ),
        ],
      ))?.path,
);
