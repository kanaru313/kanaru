import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'home_body.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.homeGreetingMorning;
    if (hour < 18) return l10n.homeGreetingAfternoon;
    return l10n.homeGreetingEvening;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final hasDatabase = ref.watch(libraryDatabaseProvider) != null;
    final hasTracks = ref.watch(homeHasTracksProvider);
    final Widget body;
    if (hasDatabase && !hasTracks.hasValue) {
      // First read, or it failed: blank, as neither says the library is
      // empty, and a spinner would only flash.
      body = const SizedBox.shrink();
    } else if (hasDatabase && (hasTracks.value ?? false)) {
      body = const HomeBody();
    } else {
      body = EmptyState(
        icon: AppIcons.library,
        title: l10n.libraryEmptyTitle,
        message: l10n.libraryEmptyMessage,
      );
    }
    return PageScaffold(
      title: _greeting(l10n),
      subtitle: l10n.homeSubtitle,
      body: body,
    );
  }
}
