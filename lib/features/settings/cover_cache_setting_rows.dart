import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'setting_row.dart';

/// Cover cache options, at the end of the library scan section. Not wired
/// yet: the button that clears the cached covers stays disabled.
class CoverCacheSettingRows extends StatelessWidget {
  const CoverCacheSettingRows({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow.single(
          title: l10n.settingsClearCoverCache,
          subtitle: l10n.settingsClearCoverCacheHint,
          comingSoon: true,
          control: FilledButton.tonal(
            style: settingButtonStyle().copyWith(
              // Red only while live; disabled keeps the normal disabled color.
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? null
                    : Theme.of(context).colorScheme.error,
              ),
            ),
            onPressed: null,
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
