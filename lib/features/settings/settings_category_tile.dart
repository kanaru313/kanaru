import 'package:material_ui/material_ui.dart';

import '../../shared/icons/app_icons.dart';

/// One entry of the Settings root: a round icon, a title, a short static
/// description and a chevron. It never navigates; the caller passes [onTap].
class SettingsCategoryTile extends StatelessWidget {
  const SettingsCategoryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      minTileHeight: 72,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(
        description,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: onTap,
    );
  }
}
