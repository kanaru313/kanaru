import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';

/// The folders chosen on the welcome screen: the pre-checked suggestion, if
/// any, followed by the folders the user added.
class OnboardingFolderList extends StatelessWidget {
  const OnboardingFolderList({
    super.key,
    required this.suggestion,
    required this.suggestionSelected,
    required this.onSuggestionChanged,
    required this.folders,
    required this.onRemove,
  });

  /// The suggested music folder; `null` hides the suggestion row.
  final String? suggestion;
  final bool suggestionSelected;
  final ValueChanged<bool> onSuggestionChanged;

  /// Folders added with the picker.
  final List<String> folders;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final suggested = suggestion;

    if (suggested == null && folders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          l10n.onboardingNoFolders,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (suggested != null)
          CheckboxListTile(
            value: suggestionSelected,
            onChanged: (value) => onSuggestionChanged(value ?? false),
            secondary: const Icon(AppIcons.folderSpecial),
            title: Text(suggested, overflow: TextOverflow.ellipsis),
            subtitle: Text(l10n.onboardingSuggested),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        for (final folder in folders)
          ListTile(
            leading: const Icon(AppIcons.folderOutlined),
            title: Text(folder, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(AppIcons.close),
              tooltip: l10n.onboardingRemoveFolder,
              onPressed: () => onRemove(folder),
            ),
          ),
      ],
    );
  }
}
