import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugin_record.dart';
import '../../core/lyrics/plugins/plugin_data_stats_provider.dart';
import '../../core/lyrics/plugins/store/plugin_config_schema_codec.dart';
import '../../l10n/l10n.dart';
import 'plugin_record_text.dart';

/// Asks whether to uninstall [record], and says what goes ("Sẽ bị xóa") and
/// what stays ("Vẫn giữ"), with the numbers in [stats]. Completes with `true`
/// only when the user confirms.
Future<bool> confirmPluginUninstall(
  BuildContext context,
  LyricsPluginRecord record,
  PluginDataStats stats,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _UninstallDialog(record: record, stats: stats),
  );
  return confirmed ?? false;
}

class _UninstallDialog extends StatelessWidget {
  const _UninstallDialog({required this.record, required this.stats});

  final LyricsPluginRecord record;
  final PluginDataStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasSecret = record.config.any(isSecretField);
    return AlertDialog(
      title: Text(l10n.pluginUninstallTitle(record.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              pluginByline(l10n, record),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _Box(
              title: l10n.pluginUninstallRemoves,
              items: [
                l10n.pluginUninstallCode,
                hasSecret
                    ? l10n.pluginUninstallSettingsSecret
                    : l10n.pluginUninstallSettings,
                l10n.pluginUninstallStorage(
                  pluginSizeText(l10n, stats.storageBytes),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Box(
              title: l10n.pluginUninstallKeeps,
              items: [
                stats.foundCount > 0
                    ? l10n.pluginUninstallKeepLyrics(stats.foundCount)
                    : l10n.pluginUninstallKeepPinned,
                l10n.pluginUninstallKeepLrc,
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.pluginUninstallConfirm),
        ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('•  $item', style: theme.textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}
