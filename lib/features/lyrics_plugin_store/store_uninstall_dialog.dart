import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugin_record.dart';
import '../../core/lyrics/plugins/store/plugin_config_schema_codec.dart';
import '../../l10n/l10n.dart';
import 'install_problem_dialog.dart';

/// "Gỡ (name)?": says what goes and what stays. Completes with `true` only
/// when the user confirms.
Future<bool> confirmStoreUninstall(
  BuildContext context,
  LyricsPluginRecord record,
) async {
  final l10n = context.l10n;
  final colors = Theme.of(context).colorScheme;
  // The author is what the plugin says about itself, and may be absent.
  final author = record.author;
  final subtitle = author == null || author.isEmpty
      ? 'v${record.version}'
      : '${l10n.lyricsStoreItemAuthor(author)} · v${record.version}';
  final hasSecret = record.config.any(isSecretField);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.lyricsStoreUninstallTitle(record.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            ProblemBox(
              error: false,
              title: l10n.lyricsStoreUninstallRemoves,
              lines: [
                l10n.lyricsStoreUninstallCode,
                hasSecret
                    ? l10n.lyricsStoreUninstallSettingsSecret
                    : l10n.lyricsStoreUninstallSettings,
                l10n.lyricsStoreUninstallStorage,
              ],
            ),
            const SizedBox(height: 8),
            ProblemBox(
              error: false,
              title: l10n.lyricsStoreUninstallKeeps,
              lines: [
                l10n.lyricsStoreUninstallKeepLyrics,
                l10n.lyricsStoreUninstallKeepLrc,
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
          child: Text(l10n.lyricsStoreUninstallConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
