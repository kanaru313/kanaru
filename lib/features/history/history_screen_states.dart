import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/empty_state.dart';

/// Shown when the app has no library database to read plays from.
class HistoryUnavailable extends StatelessWidget {
  const HistoryUnavailable({super.key});

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: AppIcons.history,
    title: context.l10n.historyUnavailable,
  );
}

/// Shown when reading the plays failed; the details are in the log.
class HistoryLoadFailed extends StatelessWidget {
  const HistoryLoadFailed({super.key});

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: AppIcons.warningOutlined,
    title: context.l10n.navHistory,
    message: context.l10n.historyLoadFailed,
  );
}

/// Shown when nothing was played yet. Says so when recording is turned off,
/// as that is the reason nothing will appear.
class HistoryEmpty extends ConsumerWidget {
  const HistoryEmpty({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final recording = ref.watch(
      settingsProvider.select((s) => s.recordListenHistory),
    );
    return EmptyState(
      icon: AppIcons.history,
      title: l10n.navHistory,
      message: l10n.historyEmptyMessage,
      action: recording
          ? null
          : Text(
              l10n.historyRecordingOff,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}
