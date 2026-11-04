import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'setting_row.dart';

/// Listen history rows (STAT-10): whether listens are recorded.
/// (Clearing listen history is located in Settings › Advanced › Danger zone).
class ListenHistorySettingRows extends ConsumerWidget {
  const ListenHistorySettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

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
      ],
    );
  }
}
