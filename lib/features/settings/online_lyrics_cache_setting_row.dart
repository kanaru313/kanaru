import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/online_lyrics_queries.dart';
import '../../core/lyrics/online/online_lyrics_lookups.dart';
import '../../core/lyrics/online/online_lyrics_streams.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'setting_row.dart';
import 'settings_confirm_dialog.dart';
import 'settings_number_presets.dart';

final _log = Logger('settings');

/// The saved online lyrics, live: songs with lyrics (found or picked), their
/// size, songs the service had none for, source choices and rejected
/// versions. A button deletes all of it after a confirmation and forgets the
/// remembered lookup failures and the pause. `.lrc` files stay. Off while
/// nothing is stored, without a library database, and while a clear runs.
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
    // throw nor lose the result, nor skip forgetting the remembered failures.
    final messenger = ScaffoldMessenger.of(context);
    final backoff = ref.read(onlineLyricsBackoffProvider.notifier);
    final lookups = ref.read(onlineLyricsLookupsProvider.notifier);
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
    if (ok) {
      backoff.clear();
      lookups.forgetFailures();
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
        (found: 0, notFound: 0, picks: 0, choices: 0, rejects: 0, bytes: 0);
    final songs = stats.found + stats.picks;
    final segments = [
      if (songs > 0) l10n.settingsSavedLyricsSongs(songs),
      if (stats.bytes > 0) formatBytes(l10n, stats.bytes),
      if (stats.notFound > 0) l10n.settingsSavedLyricsNotFound(stats.notFound),
      if (stats.choices > 0) l10n.settingsSavedLyricsChoices(stats.choices),
      if (stats.rejects > 0) l10n.settingsSavedLyricsRejects(stats.rejects),
    ];
    // Every stored row sits in one of found, notFound, picks, choices or
    // rejects, so a stored row always gives a segment and enables Clear.
    final empty = segments.isEmpty;
    final canClear =
        !_clearing && !empty && ref.watch(libraryDatabaseProvider) != null;
    return SettingRow.single(
      title: l10n.settingsSavedLyrics,
      subtitle: empty ? l10n.settingsSavedLyricsNone : segments.join(' · '),
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
