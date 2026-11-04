import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../core/stats/listen_recorder_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../../shared/widgets/confirm_dialog.dart';
import 'setting_row.dart';
import 'settings_busy_tasks.dart';

final _noClear = ValueNotifier<bool>(false);

/// Danger Zone rows: Clear listen history and Reset all settings to defaults.
class DangerZoneSettingRows extends ConsumerStatefulWidget {
  const DangerZoneSettingRows({super.key});

  @override
  ConsumerState<DangerZoneSettingRows> createState() =>
      _DangerZoneSettingRowsState();
}

class _DangerZoneSettingRowsState extends ConsumerState<DangerZoneSettingRows> {
  Future<void> _clearListenHistory() async {
    final recorder = ref.read(listenRecorderProvider);
    if (recorder == null || ref.read(settingsBusyTasksProvider).isNotEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final busy = ref.read(settingsBusyTasksProvider.notifier);
    final l10n = context.l10n;
    final confirmed = await confirmAction(
      context,
      title: l10n.listenHistoryClearTitle,
      body: l10n.listenHistoryClearBody,
      confirmLabel: l10n.listenHistoryClearButton,
    );
    if (!confirmed || !mounted) return;
    if (!busy.start(SettingsTask.listenHistory)) return;
    int? removed;
    try {
      removed = await recorder.clearHistory();
    } finally {
      busy.finish(SettingsTask.listenHistory);
    }
    messenger.showSnackBar(
      appSnackBar(
        kind: removed == null ? AppSnackBarKind.error : AppSnackBarKind.success,
        title: removed == null
            ? l10n.listenHistoryClearFailed
            : l10n.listenHistoryCleared(removed),
      ),
    );
  }

  Future<void> _resetAllSettings() async {
    if (ref.read(settingsBusyTasksProvider).isNotEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final confirmed = await confirmAction(
      context,
      title: l10n.settingsResetAllConfirmTitle,
      body: l10n.settingsResetAllConfirmBody,
      confirmLabel: l10n.settingsResetAllButton,
    );
    if (!confirmed || !mounted) return;
    final busy = ref.read(settingsBusyTasksProvider.notifier);
    if (!busy.start(SettingsTask.resetAll)) return;
    try {
      ref.read(settingsProvider.notifier).resetAllSettings();
      messenger.showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.success,
          title: l10n.settingsResetAllSuccess,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.error,
          title: l10n.settingsResetAllFailed,
        ),
      );
    } finally {
      busy.finish(SettingsTask.resetAll);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final recorder = ref.watch(listenRecorderProvider);
    final anyBusy = ref.watch(
      settingsBusyTasksProvider.select((s) => s.isNotEmpty),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow.single(
          title: l10n.listenHistoryClear,
          subtitle: l10n.settingsClearListenHistoryHint,
          control: ValueListenableBuilder<bool>(
            valueListenable: recorder?.clearing ?? _noClear,
            builder: (context, clearing, _) => FilledButton.tonal(
              style: settingButtonStyle(),
              onPressed: recorder != null && !anyBusy && !clearing
                  ? _clearListenHistory
                  : null,
              child: Text(
                l10n.listenHistoryClearButton,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        SettingRow.single(
          title: l10n.settingsResetAllTitle,
          subtitle: l10n.settingsResetAllHint,
          control: FilledButton.tonal(
            style: settingButtonStyle(),
            onPressed: !anyBusy ? _resetAllSettings : null,
            child: Text(
              l10n.settingsResetAllButton,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
