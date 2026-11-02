import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/playlist_rows.dart';
import '../../../shared/widgets/context_menu_more_button.dart';
import 'open_playlist_modal.dart';

/// The ⋮ button of a playlist row or page: opens the playlist modal. Always
/// visible, so the modal is reachable without a right click or a long press.
class PlaylistMoreButton extends ConsumerWidget {
  const PlaylistMoreButton({
    super.key,
    required this.playlist,
    required this.coverKeys,
    this.showGoTo = true,
    this.beforeRead,
    this.color,
  });

  final PlaylistSummary playlist;
  final List<String> coverKeys;
  final bool showGoTo;
  final Future<void> Function()? beforeRead;

  /// Icon color; null keeps the theme's.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open({required bool viaKeyboard, required Offset at}) =>
        openPlaylistModal(
          context,
          ref,
          playlist: playlist,
          coverKeys: coverKeys,
          showGoTo: showGoTo,
          viaKeyboard: viaKeyboard,
          beforeRead: beforeRead,
        );
    return ContextMenuMoreButton(onOpen: open, color: color);
  }
}
