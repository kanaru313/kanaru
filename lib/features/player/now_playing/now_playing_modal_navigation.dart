import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/layered_modal/layered_modal_stack.dart';
import 'now_playing_open_provider.dart';

/// Closes the modal stack that contains [modalContext] (the parent modal's
/// context, so any child modal above it closes too), closes Now Playing, and
/// goes to [location].
///
/// The router and provider container are captured before popping so the
/// navigation still runs after the modal routes leave the tree.
void leaveNowPlayingTo(BuildContext modalContext, String location) {
  final router = GoRouter.maybeOf(modalContext);
  final container = ProviderScope.containerOf(modalContext, listen: false);
  closeLayeredModalStack(modalContext);
  container.read(nowPlayingOpenProvider.notifier).close();
  router?.go(location);
}
