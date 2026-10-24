import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/home_windows.dart';
import '../../l10n/l10n.dart';
import 'home_added_window_chips.dart';
import 'home_locations.dart';
import 'home_paged_providers.dart';
import 'home_providers.dart';
import 'home_track_list_screen.dart';

/// The full "recently added" list. It opens on [initialWindow] (from the
/// location), or on the window in effect on Home when there is none. Picking
/// a chip remembers it for Home too and swaps the location, so the list reads
/// again from the top.
class HomeRecentlyAddedScreen extends ConsumerWidget {
  const HomeRecentlyAddedScreen({super.key, this.initialWindow});

  final HomeAddedWindow? initialWindow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window =
        initialWindow ?? ref.watch(homeEffectiveAddedWindowProvider).value;
    final l10n = context.l10n;
    // Until the default window is known there is nothing to read.
    if (window == null) return const SizedBox.shrink();
    return HomeTrackListScreen(
      // A new window is a new list: its own scroll position and rows.
      key: ValueKey(window),
      title: l10n.homeRecentlyAddedTitle,
      emptyText: l10n.homeRecentlyAddedEmpty,
      pages: homeRecentlyAddedPagesProvider(window),
      header: HomeAddedWindowChips(
        selected: window,
        onPicked: (picked) {
          ref.read(homeAddedWindowChoiceProvider.notifier).select(picked);
          context.replace(homeRecentlyAddedLocation(picked));
        },
      ),
    );
  }
}
