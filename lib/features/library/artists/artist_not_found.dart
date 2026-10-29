import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_scaffold.dart';

/// Shown where an artist page or list would be when its key is broken or the
/// artist has no songs left.
class ArtistNotFound extends StatelessWidget {
  const ArtistNotFound({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageScaffold(
      title: l10n.navArtists,
      body: EmptyState(
        icon: AppIcons.artistOutline,
        title: l10n.artistsNotFound,
        message: l10n.artistsNotFoundMessage,
      ),
    );
  }
}
