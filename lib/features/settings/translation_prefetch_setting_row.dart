import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'setting_choice.dart';
import 'setting_row.dart';

/// "Translate ahead": how many upcoming songs are translated before they play.
/// Locked until a default service is chosen. Going up from 0 asks first,
/// because lyrics, titles and artists of songs the user has not played yet are
/// then sent to the service.
class TranslationPrefetchSettingRow extends ConsumerStatefulWidget {
  const TranslationPrefetchSettingRow({super.key});

  @override
  ConsumerState<TranslationPrefetchSettingRow> createState() =>
      _TranslationPrefetchSettingRowState();
}

class _TranslationPrefetchSettingRowState
    extends ConsumerState<TranslationPrefetchSettingRow> {
  /// Keys the dropdown. Changes only when the user cancels the notice: the
  /// dropdown has already written the cancelled choice into its text field, so
  /// it is rebuilt from the saved value.
  int _dropdownEpoch = 0;

  Future<void> _pick(int count) async {
    final before = ref.read(settingsProvider).translation.prefetchCount;
    if (count == before) return;
    if (before == 0 && !await _confirmNotice()) {
      if (mounted) setState(() => _dropdownEpoch++);
      return;
    }
    if (!mounted) return;
    // Read after the dialog: the settings may have changed meanwhile.
    final prefs = ref.read(settingsProvider).translation;
    ref
        .read(settingsProvider.notifier)
        .setTranslation(prefs.copyWith(prefetchCount: count));
  }

  Future<bool> _confirmNotice() async {
    final l10n = context.l10n;
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsTranslationPrefetch),
        content: Text(l10n.settingsTranslationPrefetchNotice),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prefs = ref.watch(settingsProvider.select((s) => s.translation));
    return SettingRow.single(
      title: l10n.settingsTranslationPrefetch,
      subtitle: l10n.settingsTranslationPrefetchHint,
      control: SettingDropdown<int>(
        key: ValueKey(_dropdownEpoch),
        selected: prefs.prefetchCount,
        enabled: prefs.service != null,
        onSelected: _pick,
        options: [
          SettingOption(value: 0, label: l10n.settingsTranslationPrefetchNone),
          for (var n = 1; n <= TranslationPrefs.maxPrefetchCount; n++)
            SettingOption(
              value: n,
              label: l10n.settingsTranslationPrefetchCount(n),
            ),
        ],
      ),
    );
  }
}
