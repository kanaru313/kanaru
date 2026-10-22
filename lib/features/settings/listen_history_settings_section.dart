import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../core/stats/listen_recorder_provider.dart';
import '../../l10n/l10n.dart';
import 'setting_row.dart';
import 'settings_confirm_dialog.dart';
import 'settings_section.dart';

/// Listen history settings (STAT-10): whether listens are recorded, and a
/// button that removes every recorded listen after a confirmation. The
/// switch is only a preference, so it works without a library; the button
/// needs the library database and is off while a clear runs.
class ListenHistorySettingsSection extends ConsumerStatefulWidget {
  const ListenHistorySettingsSection({super.key});

  @override
  ConsumerState<ListenHistorySettingsSection> createState() =>
      _ListenHistorySettingsSectionState();
}

class _ListenHistorySettingsSectionState
    extends ConsumerState<ListenHistorySettingsSection> {
  bool _clearing = false;

  Future<void> _clear() async {
    final recorder = ref.read(listenRecorderProvider);
    if (recorder == null || _clearing) return;
    // Taken before any await: leaving Settings during a long clear must
    // neither throw nor lose the result.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.listenHistoryClearTitle,
      body: l10n.listenHistoryClearBody,
      confirmLabel: l10n.listenHistoryClearButton,
    );
    if (!confirmed || !mounted) return;
    setState(() => _clearing = true);
    final removed = await recorder.clearHistory();
    if (mounted) setState(() => _clearing = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          removed == null
              ? l10n.listenHistoryClearFailed
              : l10n.listenHistoryCleared(removed),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canClear = ref.watch(listenRecorderProvider) != null && !_clearing;

    return SettingsSection(
      title: l10n.listenHistorySection,
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
