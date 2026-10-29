import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/section_heading.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(title: title, onSeeAll: onSeeAll),
        ?below,
        child,
      ],
    );
  }
}
