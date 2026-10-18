import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_scaffold.dart';

/// One browsing page of the library (songs, albums, artists…). Shows an
/// empty state until the library database exists.
class LibrarySectionScreen extends StatelessWidget {
  const LibrarySectionScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final String title;
  final IconData icon;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: title,
      body: EmptyState(icon: icon, title: emptyTitle, message: emptyMessage),
    );
  }
}
