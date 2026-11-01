import 'dart:async';

import 'package:file_selector/file_selector.dart' as picker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/lyrics_plugin_spec.dart' show PluginKind;
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

/// The kind chip (Lyrics or Translate) the user picked on the store page;
/// null until then, when the kind the mount starts on applies. Reset when the
/// page closes.
class PluginStoreKind extends Notifier<PluginKind?> {
  PluginStoreKind(this.initialKind);

  /// The kind of the mount this pick belongs to; it keeps the picks of two
  /// mounts apart.
  final PluginKind initialKind;

  @override
  PluginKind? build() => null;

  void set(PluginKind value) => state = value;
}

final pluginStoreKindProvider = NotifierProvider.autoDispose
    .family<PluginStoreKind, PluginKind?, PluginKind>(PluginStoreKind.new);

/// The store list: records and repositories with the search text and the
/// chosen chip applied. A chip whose repository was removed (or whose
/// plugins from files are gone) counts as "all".
///
/// The argument is the kind the page starts on, used until a chip is picked.
final pluginStoreViewProvider = Provider.autoDispose
    .family<AsyncValue<PluginStoreView>, PluginKind>((ref, initialKind) {
      final raw = ref.watch(pluginStoreRawInputProvider);
      final search = ref.watch(pluginStoreSearchProvider);
      final chosen = ref.watch(pluginStoreFilterProvider);
      final kind =
          ref.watch(pluginStoreKindProvider(initialKind)) ?? initialKind;
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
            kind: kind,
            filter: known ? chosen : const StoreSourceFilter.all(),
            available: input.available,
          ),
        );
      });
    });

/// Install ids being updated right now, for the spinners on the rows. The
/// controller's stream is subscribed before the current set is added, so no
/// change slips in between.
final pluginStoreUpdatingProvider = StreamProvider.autoDispose<Set<String>>((
  ref,
) {
  final controller = ref.watch(lyricsPluginReposControllerProvider);
  if (controller == null) return const Stream.empty();
  final out = StreamController<Set<String>>();
  final sub = controller.updatingChanges.listen(out.add, onError: out.addError);
  out.add(controller.updating);
  ref.onDispose(() {
    sub.cancel();
    out.close();
  });
  return out.stream;
});

/// Installs started from this screen and not finished, by [pendingInstallKey], [pendingUpdateAllKey]
/// or [pendingUninstallKey]: the row shows a spinner and cannot be tapped again.
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

/// The pending key of a running "update all".
const pendingUpdateAllKey = 'update-all';

/// The key of the install of plugin [slug] of the repository [repoUrl].
String pendingInstallKey(String repoUrl, String slug) => '$repoUrl\n$slug';

/// The key of the uninstall of the plugin installed as [installId].
String pendingUninstallKey(String installId) => 'uninstall\n$installId';

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
