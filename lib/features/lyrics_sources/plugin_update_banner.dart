import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugin_record.dart';
import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import '../../core/lyrics/plugins/repo/plugin_update_check.dart';
import '../../l10n/l10n.dart';
import '../../shared/lyrics_plugins/plugin_failure_text.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'plugin_updating_ids_provider.dart';

final _log = Logger('lyrics_sources');

/// A "New version" banner with an Update button, on the page of an installed
/// plugin whose repository lists a newer version. Shows nothing for a plugin
/// from a file, a removed plugin, a repository that was removed, or when no
/// repository controller exists. The button also waits while the core updates
/// this plugin from elsewhere. The result of our own update is reported with a
/// snackbar, so it still shows if the page closes meanwhile.
class PluginUpdateBanner extends ConsumerStatefulWidget {
  const PluginUpdateBanner({super.key, required this.record});

  final LyricsPluginRecord record;

  @override
  ConsumerState<PluginUpdateBanner> createState() => _PluginUpdateBannerState();
}

class _PluginUpdateBannerState extends ConsumerState<PluginUpdateBanner> {
  /// Our own update is running; the button waits for it.
  bool _updating = false;

  Future<void> _update() async {
    // Taken before the awaits: the page may close meanwhile.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final name = widget.record.name;
    final controller = ref.read(lyricsPluginReposControllerProvider);
    if (controller == null || _updating) return;
    setState(() => _updating = true);
    try {
      final result = await controller.update(widget.record.installId);
      messenger.showSnackBar(switch (result) {
        RepoPluginDone(:final record) => appSnackBar(
          kind: AppSnackBarKind.success,
          title: l10n.lyricsStoreUpdated(record.name, record.version),
        ),
        // The list was stale: this version is already installed.
        RepoPluginFailed(failure: RepoPluginFailure.noNewerVersion) =>
          appSnackBar(
            kind: AppSnackBarKind.info,
            title: l10n.lyricsStoreFailNoNewerVersion,
          ),
        final RepoPluginFailed failed => appSnackBar(
          kind: AppSnackBarKind.error,
          title: l10n.pluginUpdateFailed(name),
          details: repoPluginFailureText(l10n, failed),
        ),
      });
    } catch (error, stackTrace) {
      _log.warning('Updating a plugin failed', error, stackTrace);
      messenger.showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.error,
          title: l10n.pluginUpdateFailed(name),
        ),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repos = ref.watch(lyricsPluginReposProvider).asData?.value;
    final hasController =
        ref.watch(lyricsPluginReposControllerProvider) != null;
    if (repos == null || !hasController) return const SizedBox.shrink();
    final entry = availableUpdate(widget.record, {
      for (final repo in repos) repo.url: repo,
    });
    if (entry == null) return const SizedBox.shrink();
    final busy =
        _updating ||
        (ref
                .watch(pluginUpdatingIdsProvider)
                .asData
                ?.value
                .contains(widget.record.installId) ??
            false);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.pluginUpdateAvailable(entry.version),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              FilledButton(
                onPressed: busy ? null : _update,
                child: busy
                    ? Semantics(
                        label: l10n.lyricsStoreWorking,
                        child: const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Text(l10n.pluginUpdateAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
