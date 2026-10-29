import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_scaffold.dart';

/// Shown where a genre page or list would be when its key is broken or the
/// genre has no songs left.
class GenreNotFound extends StatelessWidget {
  const GenreNotFound({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageScaffold(
      title: l10n.genresTitle,
      body: EmptyState(
        icon: AppIcons.genreOutlined,
        title: l10n.genresNotFound,
        message: l10n.genresNotFoundMessage,
      ),
    );
  }
}
