import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/lyrics_source_routes.dart';

/// The plugin list could not be read; offers a retry.
class PluginDetailLoadFailed extends StatelessWidget {
  const PluginDetailLoadFailed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.pluginSourcesLoadFailed),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: Text(l10n.pluginRetry)),
        ],
      ),
    );
  }
}

/// The plugin is no longer installed; offers the way back to the list.
class PluginDetailGone extends StatelessWidget {
  const PluginDetailGone({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.pluginGone),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => context.go(lyricsSourcesRoute),
            child: Text(l10n.lyricsSourcesTitle),
          ),
        ],
      ),
    );
  }
}
