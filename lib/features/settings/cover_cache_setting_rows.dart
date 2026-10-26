import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_cache_clear.dart';
import '../../core/indexer/indexer_providers.dart';
import '../../core/indexer/indexer_state.dart';
import '../../l10n/l10n.dart';
import 'setting_row.dart';
import 'settings_confirm_dialog.dart';
import '../../shared/widgets/app_snack_bar.dart';

final _log = Logger('settings');

/// Cover cache options, at the end of the library scan section: a button
/// that deletes the cover thumbnails after a confirmation, then rescans so
/// the covers are made again. Off without a library or a cache folder, while
/// a scan or its cover pass runs, and while a clear runs.
class CoverCacheSettingRows extends ConsumerStatefulWidget {
  const CoverCacheSettingRows({super.key});

  @override
  ConsumerState<CoverCacheSettingRows> createState() =>
      _CoverCacheSettingRowsState();
}

class _CoverCacheSettingRowsState extends ConsumerState<CoverCacheSettingRows> {
  bool _clearing = false;

  /// Whether the button may run now: also checked again once the dialog
  /// closes, since a scan may have started while it was open.
  bool _canClear() =>
      !_clearing &&
      ref.read(libraryDatabaseProvider) != null &&
      ref.read(coverCacheDirectoryProvider) != null &&
      ref.read(libraryIndexerProvider) is! IndexerScanning &&
      ref.read(coverPassProvider) is! CoverPassRunning;

  Future<void> _clear() async {
    if (!_canClear()) return;
    // Taken before any await: leaving Settings during the clear must
    // neither throw nor skip the rescan that brings the covers back.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final indexer = ref.read(libraryIndexerProvider.notifier);
    final directory = ref.read(coverCacheDirectoryProvider)!;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.coverCacheClearTitle,
      body: l10n.coverCacheClearBody,
      confirmLabel: l10n.settingsClearCoverCacheButton,
    );
    if (!confirmed || !mounted || !_canClear()) return;
    setState(() => _clearing = true);
    int? deleted;
    try {
      deleted = await clearCoverCache(directory, before: DateTime.now());
    } catch (error, stackTrace) {
      _log.warning('Clearing the cover cache failed', error, stackTrace);
    }
    if (mounted) setState(() => _clearing = false);
    if (deleted == null) {
      messenger.showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.error,
          title: l10n.coverCacheClearFailed,
        ),
      );
      return;
    }
    // Decoded pictures of the deleted files would otherwise stay on screen.
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    messenger.showSnackBar(
      appSnackBar(
        kind: AppSnackBarKind.success,
        title: l10n.coverCacheCleared(deleted),
      ),
    );
    // The scan's repair finds every thumbnail gone and its cover pass makes
    // them again; a scan already running is followed by another.
    indexer.scan().ignore();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canClear =
        !_clearing &&
        ref.watch(libraryDatabaseProvider) != null &&
        ref.watch(coverCacheDirectoryProvider) != null &&
        ref.watch(
          libraryIndexerProvider.select((s) => s is! IndexerScanning),
        ) &&
        ref.watch(coverPassProvider.select((s) => s is! CoverPassRunning));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow.single(
          title: l10n.settingsClearCoverCache,
          subtitle: l10n.settingsClearCoverCacheHint,
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
              l10n.settingsClearCoverCacheButton,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
