import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/lyric_translation_queries.dart';
import '../../core/lyrics_translation/translation_providers.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'setting_row.dart';
import 'settings_number_presets.dart';
import 'settings_confirm_dialog.dart';

final _log = Logger('settings');

/// The saved lyrics translations: how many songs and how much space they
/// take, live, and a button that deletes them after a confirmation. The
/// translation settings stay. Off while there is nothing saved, without a
/// library database, and while a clear runs.
class TranslationCacheSettingRow extends ConsumerStatefulWidget {
  const TranslationCacheSettingRow({super.key});

  @override
  ConsumerState<TranslationCacheSettingRow> createState() =>
      _TranslationCacheSettingRowState();
}

class _TranslationCacheSettingRowState
    extends ConsumerState<TranslationCacheSettingRow> {
  bool _clearing = false;

  Future<void> _clear() async {
    final db = ref.read(libraryDatabaseProvider);
    if (db == null || _clearing) return;
    // Taken before any await: leaving Settings during the clear must neither
    // throw nor lose the result.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.translationCacheClearTitle,
      body: l10n.translationCacheClearBody,
      confirmLabel: l10n.settingsClear,
    );
    if (!confirmed || !mounted) return;
    setState(() => _clearing = true);
    int? removed;
    try {
      removed = await db.clearLyricTranslations();
    } catch (error, stackTrace) {
      _log.warning('Clearing saved translations failed', error, stackTrace);
    }
    if (mounted) setState(() => _clearing = false);
    messenger.showSnackBar(
      appSnackBar(
        kind: removed == null ? AppSnackBarKind.error : AppSnackBarKind.success,
        title: removed == null
            ? l10n.translationCacheClearFailed
            : l10n.translationCacheCleared(removed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats =
        ref.watch(translationCacheStatsProvider).value ?? (count: 0, bytes: 0);
    final canClear =
        !_clearing &&
        stats.count > 0 &&
        ref.watch(libraryDatabaseProvider) != null;
    return SettingRow.single(
      title: l10n.settingsTranslationCache,
      subtitle: stats.count == 0
          ? l10n.translationCacheEmpty
          : l10n.translationCacheSummary(
              stats.count,
              formatBytes(l10n, stats.bytes),
            ),
      control: FilledButton.tonal(
        style: settingButtonStyle().copyWith(
          // Red only while live; disabled keeps the normal disabled color.
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? null
                : Theme.of(context).colorScheme.error,
          ),
        ),
        onPressed: canClear ? _clear : null,
        child: Text(
          l10n.settingsClear,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
