import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';

/// One block of the Home page: a title with a "see all" button beside it, an
/// optional [below] widget (chips), then the [child] row. The horizontal
/// margin of 32 matches PageScaffold.
class HomeSection extends StatelessWidget {
  const HomeSection({
    super.key,
    required this.title,
    required this.child,
    this.onSeeAll,
    this.below,
  });

  final String title;

  /// Opens the full list; the button stays in place but is disabled when null.
  final VoidCallback? onSeeAll;
  final Widget? below;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 24, 0),
          child: Row(
            children: [
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.homeSeeAll,
                icon: const Icon(AppIcons.chevronRight),
                onPressed: onSeeAll,
              ),
            ],
          ),
        ),
        ?below,
        child,
      ],
    );
  }
}
