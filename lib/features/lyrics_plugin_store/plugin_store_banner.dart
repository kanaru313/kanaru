import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'plugin_store_actions.dart';
import 'repo_error_text.dart';

/// The banner at the top of the store when repositories failed to load: the
/// name and reason for one, a count for several, and "Thử lại". Nothing when
/// none failed.
class PluginStoreBanner extends ConsumerWidget {
  const PluginStoreBanner({super.key, required this.failing});

  final List<FailingRepo> failing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (failing.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final one = failing.length == 1 ? failing.single : null;
    final text = one == null
        ? l10n.lyricsStoreRepoFailedMany(failing.length)
        : l10n.lyricsStoreRepoFailedOne(
            one.name,
            repoLoadReasonText(l10n, one.error),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            children: [
              Icon(AppIcons.warningOutlined, color: colors.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: () {
                  final actions = PluginStoreActions(context);
                  one == null
                      ? actions.refreshAll()
                      : actions.refreshOne(one.url);
                },
                child: Text(l10n.lyricsStoreRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
