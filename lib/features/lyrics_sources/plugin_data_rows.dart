import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/lyrics_plugin_spec.dart'
    show lyricsPluginDataMaxBytes;
import '../../core/lyrics/plugins/lyrics_plugins_provider.dart';
import '../../core/lyrics/plugins/plugin_data_stats_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/lyrics_plugins/plugin_record_text.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'plugin_confirm_dialog.dart';
import 'plugin_section_title.dart';

final _log = Logger('lyrics_sources');

/// "Dữ liệu": the plugin's own storage and the lyrics saved from it, each
/// with a Delete button that asks first.
class PluginDataRows extends ConsumerWidget {
  const PluginDataRows({super.key, required this.record});

  final LyricsPluginRecord record;

  Future<void> _clear(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String body,
    required String done,
    required Future<bool?> Function(LyricsPluginsController c) run,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final controller = ref.read(lyricsPluginsControllerProvider);
    if (controller == null) return;
    final confirmed = await confirmPluginAction(
      context,
      title: title,
      body: body,
      confirmLabel: l10n.pluginDataClear,
    );
    if (!confirmed) return;
    bool? ok = true;
    try {
      ok = await run(controller);
    } catch (error, stackTrace) {
      _log.warning('Clearing plugin data failed', error, stackTrace);
      ok = false;
    }
    if (!context.mounted) return;
    ref.invalidate(pluginDataStatsProvider(record.installId));
    // Null: the plugin is gone, and its page already says so.
    if (ok == null) return;
    messenger.showSnackBar(
      appSnackBar(
        kind: ok ? AppSnackBarKind.success : AppSnackBarKind.error,
        title: ok ? done : l10n.pluginDataFailed,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stats = ref.watch(pluginDataStatsProvider(record.installId)).value;
    final storage = stats?.storageBytes ?? 0;
    final songs = stats?.foundCount ?? 0;
    final theme = Theme.of(context);
    final canWrite = ref.watch(lyricsPluginsControllerProvider) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PluginSectionTitle(l10n.pluginDataTitle),
        ListTile(
          title: Text(l10n.pluginStorageTitle),
          subtitle: Text(
            l10n.pluginStorageUsage(
              pluginSizeText(l10n, storage),
              pluginSizeText(l10n, lyricsPluginDataMaxBytes),
            ),
          ),
          trailing: TextButton(
            onPressed: !canWrite || storage == 0
                ? null
                : () => _clear(
                    context,
                    ref,
                    title: l10n.pluginStorageClearTitle,
                    body: l10n.pluginStorageClearBody,
                    done: l10n.pluginStorageCleared,
                    run: (c) async =>
                        switch (await c.clearStorage(record.installId)) {
                          LyricsPluginWrite.written => true,
                          LyricsPluginWrite.skipped => null,
                          LyricsPluginWrite.tooLarge => false,
                        },
                  ),
            child: Text(l10n.pluginDataClear),
          ),
        ),
        ListTile(
          title: Text(l10n.pluginSavedLyricsTitle),
          subtitle: Text(
            songs == 0
                ? l10n.pluginSavedLyricsNone
                : l10n.pluginSavedLyricsSummary(
                    songs,
                    pluginSizeText(l10n, stats?.textBytes ?? 0),
                  ),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          trailing: TextButton(
            onPressed: !canWrite || songs == 0
                ? null
                : () => _clear(
                    context,
                    ref,
                    title: l10n.pluginSavedLyricsClearTitle,
                    body: l10n.pluginSavedLyricsClearBody,
                    done: l10n.pluginSavedLyricsCleared,
                    run: (c) async {
                      await c.clearSavedLyrics(record.installId);
                      return true;
                    },
                  ),
            child: Text(l10n.pluginDataClear),
          ),
        ),
      ],
    );
  }
}
