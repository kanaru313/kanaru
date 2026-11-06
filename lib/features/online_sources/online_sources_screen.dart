import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/sources/source_plugin_records.dart';
import '../../l10n/l10n.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'display_host.dart';
import 'online_result_row.dart';
import 'online_search_bar.dart';
import 'online_search_controller.dart';
import 'online_source_header.dart';
import 'online_state_views.dart';

/// "Online": search in the first installed source plugin and play a result.
/// With no source plugin it says so and points to the plugin store.
class OnlineSourcesScreen extends ConsumerWidget {
  const OnlineSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final records = ref.watch(sourcePluginRecordsProvider);
    final plugin = records.value?.firstOrNull;
    if (plugin == null) {
      return PageScaffold(
        title: l10n.navOnline,
        // The first read is not "no plugin" yet.
        body: records.isLoading
            ? const SizedBox.shrink()
            : const OnlineNoPluginView(),
      );
    }
    final controller = ref.read(onlineSearchControllerProvider.notifier);
    // What a plugin that is not the selected one left behind is not shown.
    final state = switch (ref.watch(onlineSearchControllerProvider)) {
      OnlineSearchIdle() => const OnlineSearchIdle(),
      final OnlineSearchLoading s when s.installId == plugin.installId => s,
      final OnlineSearchResults s when s.installId == plugin.installId => s,
      final OnlineSearchEmpty s when s.installId == plugin.installId => s,
      final OnlineSearchFailed s when s.installId == plugin.installId => s,
      final OnlineSearchConsent s when s.installId == plugin.installId => s,
      _ => const OnlineSearchIdle(),
    };
    return PageScaffold(
      title: plugin.name,
      subtitle: displayHost(plugin),
      actions: [OnlineSourceButton(record: plugin)],
      body: Column(
        children: [
          OnlineSearchBar(
            onSearch: (query) => controller.search(plugin.installId, query),
          ),
          Expanded(
            child: switch (state) {
              OnlineSearchIdle() => const OnlineIdleView(),
              OnlineSearchLoading() => const OnlineLoadingView(),
              OnlineSearchEmpty(:final query) => OnlineEmptyView(query: query),
              OnlineSearchResults(:final tracks) => ListView.builder(
                itemCount: tracks.length,
                itemBuilder: (context, i) => OnlineResultRow(
                  track: tracks[i],
                  onTap: () => playTracks(ref, tracks, i),
                ),
              ),
              OnlineSearchFailed(:final kind, :final message) =>
                OnlineErrorView(
                  record: plugin,
                  kind: kind,
                  message: message,
                  onRetry: controller.retry,
                ),
              OnlineSearchConsent() => OnlineConsentView(
                record: plugin,
                onAccept: controller.acceptNotice,
              ),
            },
          ),
        ],
      ),
    );
  }
}
