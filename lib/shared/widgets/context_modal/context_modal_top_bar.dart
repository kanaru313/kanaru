import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../icons/app_icons.dart';

/// Header of a sub-page: back arrow, title, then [actions] (icon buttons).
class ContextModalTopBar extends StatelessWidget {
  const ContextModalTopBar({
    super.key,
    required this.title,
    required this.onBack,
    this.actions = const [],
  });

  final String title;
  final VoidCallback onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 10, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: context.l10n.contextModalBack,
            icon: const Icon(AppIcons.back),
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
