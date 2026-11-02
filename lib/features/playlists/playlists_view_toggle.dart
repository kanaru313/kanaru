import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../shared/widgets/view_mode_toggle.dart';

/// Header button that switches the playlists page between cards and rows.
class PlaylistsViewToggle extends ConsumerWidget {
  const PlaylistsViewToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ViewModeToggle(
    view: ref.watch(settingsProvider.select((s) => s.playlistsView)),
    onChanged: ref.read(settingsProvider.notifier).setPlaylistsView,
  );
}
