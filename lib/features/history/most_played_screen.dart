import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'history_screen_states.dart';
import 'most_played_view.dart';

/// The Most played page: the songs played most in a range of days, in two
/// columns like History (the pane carries the title). Its sub-page (a song's
/// history) lives in the same router branch, so the sidebar keeps this page
/// lit.
class MostPlayedScreen extends ConsumerWidget {
  const MostPlayedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(libraryDatabaseProvider) == null) {
      return PageScaffold(
        title: context.l10n.navMostPlayed,
        body: const HistoryUnavailable(),
      );
    }
    return const MostPlayedView();
  }
}
