import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics_translation/deepl_key_provider.dart';
import '../../core/lyrics_translation/deepl_usage.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'deepl_key_dialog.dart';
import 'deepl_key_storage_notes.dart';
import 'setting_row.dart';
import 'settings_confirm_dialog.dart';

/// Plans with a character limit at or above this count as unlimited.
const _unlimitedFrom = 1000000000000;

const _masked = '••••••••';

/// The DeepL key row: add, replace, remove and the quota. Built only while
/// DeepL is the chosen service, so a Google-only user never makes the app
/// read the key store. The key itself is never drawn: only a mask. The quota
/// is asked from DeepL after a save and when the refresh icon is pressed,
/// never when Settings opens.
class DeepLKeySettingRow extends ConsumerStatefulWidget {
  const DeepLKeySettingRow({super.key});

  @override
  ConsumerState<DeepLKeySettingRow> createState() => _DeepLKeySettingRowState();
}

class _DeepLKeySettingRowState extends ConsumerState<DeepLKeySettingRow> {
  DeepLUsage? _usage;
  String? _usageError;
  bool _refreshing = false;

  Future<void> _edit({required bool replacing}) async {
    final usage = await showDeepLKeyDialog(context, replacing: replacing);
    if (usage != null && mounted) {
      setState(() {
        _usage = usage;
        _usageError = null;
      });
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final l10n = context.l10n;
    setState(() => _refreshing = true);
    // Held open so the autoDispose provider survives its own request.
    ref.invalidate(deeplUsageProvider);
    final hold = ref.listenManual(deeplUsageProvider, (_, _) {});
    try {
      final usage = await ref.read(deeplUsageProvider.future);
      if (mounted) {
        setState(() {
          _usage = usage;
          _usageError = null;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _usageError = deeplKeyErrorMessage(
            l10n,
            error,
            fallback: l10n.deeplKeyReadFailed,
          );
        });
      }
    } finally {
      hold.close();
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _clear() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(deeplApiKeyProvider.notifier);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.deeplKeyClearTitle,
      body: l10n.deeplKeyClearBody,
      confirmLabel: l10n.deeplKeyClear,
    );
    if (!confirmed) return;
    try {
      await notifier.clear();
      if (mounted) {
        setState(() {
          _usage = null;
          _usageError = null;
        });
      }
    } on Object catch (error) {
      messenger.showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.error,
          title: l10n.deeplKeyClearFailed,
          details: deeplKeyErrorMessage(
            l10n,
            error,
            fallback: l10n.deeplKeyClearFailed,
          ),
        ),
      );
    }
  }

  String _usageText(DeepLUsage usage) => usage.characterLimit >= _unlimitedFrom
      ? context.l10n.deeplKeyUsageNoLimit(usage.characterCount)
      : context.l10n.deeplKeyUsage(usage.characterCount, usage.characterLimit);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final key = ref.watch(deeplApiKeyProvider);
    final Widget row;
    if (key.isLoading) {
      row = SettingRow.single(
        title: l10n.deeplKeyTitle,
        control: const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (key.hasError) {
      row = SettingRow.single(
        title: l10n.deeplKeyTitle,
        subtitle: deeplKeyErrorMessage(
          l10n,
          key.error!,
          fallback: l10n.deeplKeyReadFailed,
        ),
        control: FilledButton.tonal(
          style: settingButtonStyle(),
          onPressed: () => ref.invalidate(deeplApiKeyProvider),
          child: Text(l10n.lyricsTranslationRetry),
        ),
      );
    } else if (key.value == null) {
      row = SettingRow.single(
        title: l10n.deeplKeyTitle,
        subtitle: l10n.deeplKeyNone,
        control: FilledButton.tonal(
          style: settingButtonStyle(),
          onPressed: () => _edit(replacing: false),
          child: Text(l10n.deeplKeyAdd),
        ),
      );
    } else {
      final usage = _usage;
      final free = usage?.freeKey ?? key.value!.trim().endsWith(':fx');
      final plan = free ? l10n.deeplKeyPlanFree : l10n.deeplKeyPlanPro;
      row = SettingRow.single(
        title: l10n.deeplKeyTitle,
        subtitle: [
          '$_masked · $plan',
          _usageError ??
              (usage == null ? l10n.deeplKeyUsageHint : _usageText(usage)),
        ].join('\n'),
        control: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.end,
          children: [
            _refreshing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: l10n.deeplKeyRefresh,
                    icon: const Icon(AppIcons.refresh),
                    onPressed: _refresh,
                  ),
            FilledButton.tonal(
              style: settingButtonStyle(),
              onPressed: () => _edit(replacing: true),
              child: Text(l10n.deeplKeyEdit),
            ),
            FilledButton.tonal(
              style: settingButtonStyle(),
              onPressed: _clear,
              child: Text(l10n.deeplKeyClear),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [row, const DeepLKeyStorageNotes()],
    );
  }
}
