import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../core/stats/listen_recorder_provider.dart';
import '../../l10n/l10n.dart';
import 'setting_row.dart';
import 'settings_busy_tasks.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/app_snack_bar.dart';

/// Listen history rows (STAT-10): whether listens are recorded, and a
/// button that removes every recorded listen after a confirmation. The
/// switch is only a preference, so it works without a library; the button
/// needs the library database and is off while a clear runs.
class ListenHistorySettingRows extends ConsumerStatefulWidget {
  const ListenHistorySettingRows({super.key});

  @override
  ConsumerState<ListenHistorySettingRows> createState() =>
      _ListenHistorySettingRowsState();
}

class _ListenHistorySettingRowsState
    extends ConsumerState<ListenHistorySettingRows> {
  Future<void> _clear() async {
    final recorder = ref.read(listenRecorderProvider);
    if (recorder == null ||
        ref
            .read(settingsBusyTasksProvider)
            .contains(SettingsTask.listenHistory)) {
      return;
    }
    // Taken before any await: leaving Settings during a long clear must
    // neither throw nor lose the result.
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canClear =
        ref.watch(listenRecorderProvider) != null &&
        !ref.watch(
          settingsBusyTasksProvider.select(
            (s) => s.contains(SettingsTask.listenHistory),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow.single(
          title: l10n.listenHistoryRecord,
          subtitle: l10n.listenHistoryRecordHint,
          control: Switch(
            value: ref.watch(
              settingsProvider.select((s) => s.recordListenHistory),
            ),
            onChanged: ref
                .read(settingsProvider.notifier)
                .setRecordListenHistory,
          ),
        ),
        SettingRow.single(
          title: l10n.listenHistoryClear,
          subtitle: l10n.settingsClearListenHistoryHint,
          control: FilledButton.tonal(
            style: settingButtonStyle(),
            onPressed: canClear ? _clear : null,
            child: Text(
              l10n.listenHistoryClearButton,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
