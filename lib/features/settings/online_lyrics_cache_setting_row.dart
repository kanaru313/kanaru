import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/online_lyrics_queries.dart';
import '../../core/lyrics/online/online_lyrics_streams.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'setting_row.dart';
import 'settings_confirm_dialog.dart';
import 'settings_number_presets.dart';

final _log = Logger('settings');

/// The saved online lyrics: songs with lyrics (found or picked), their size
/// and the songs the service had none for, live, and a button that deletes
/// all of it after a confirmation. `.lrc` files stay. Off while there is
/// nothing saved, without a library database, and while a clear runs.
class OnlineLyricsCacheSettingRow extends ConsumerStatefulWidget {
  const OnlineLyricsCacheSettingRow({super.key});

  @override
  ConsumerState<OnlineLyricsCacheSettingRow> createState() =>
      _OnlineLyricsCacheSettingRowState();
}

class _OnlineLyricsCacheSettingRowState
    extends ConsumerState<OnlineLyricsCacheSettingRow> {
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
      title: l10n.settingsSavedLyricsClearTitle,
      body: l10n.settingsSavedLyricsClearBody,
      confirmLabel: l10n.settingsSavedLyricsClear,
    );
    if (!confirmed || !mounted) return;
    setState(() => _clearing = true);
    var ok = true;
    try {
      await db.clearOnlineLyrics();
    } catch (error, stackTrace) {
      ok = false;
      _log.warning('Clearing saved online lyrics failed', error, stackTrace);
    }
    if (mounted) setState(() => _clearing = false);
    messenger.showSnackBar(
      appSnackBar(
        kind: ok ? AppSnackBarKind.success : AppSnackBarKind.error,
        title: ok
            ? l10n.settingsSavedLyricsCleared
            : l10n.settingsSavedLyricsClearFailed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats =
        ref.watch(onlineLyricsStatsProvider).value ??
        (found: 0, notFound: 0, picks: 0, skips: 0, rejects: 0, bytes: 0);
    final empty =
        stats.found +
            stats.notFound +
            stats.picks +
            stats.skips +
            stats.rejects ==
        0;
    final canClear =
        !_clearing && !empty && ref.watch(libraryDatabaseProvider) != null;
    return SettingRow.single(
      title: l10n.settingsSavedLyrics,
      subtitle: empty
          ? l10n.settingsSavedLyricsNone
          : l10n.settingsSavedLyricsSummary(
              stats.found + stats.picks,
              formatBytes(l10n, stats.bytes),
              stats.notFound,
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
          l10n.settingsSavedLyricsClear,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
