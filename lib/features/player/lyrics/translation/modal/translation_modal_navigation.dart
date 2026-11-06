import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../shared/settings_routes.dart';
import '../../../../../shared/translation_plugin_routes.dart';
import '../../../now_playing/now_playing_open_provider.dart';

/// Closes the modal route containing [modalContext] and every modal route
/// stacked above it (such as a child selection picker or a consent dialog).
///
/// Does nothing when [modalContext] is not inside an active [PopupRoute], so
/// a page route underneath the modal is never popped by mistake.
void closeTranslationModalStack(BuildContext modalContext) {
  if (!modalContext.mounted) return;
  final route = ModalRoute.of(modalContext);
  if (route is! PopupRoute || !route.isActive) return;
  final navigator = Navigator.of(modalContext);
  navigator.popUntil((r) => r == route);
  if (route.isActive) {
    navigator.pop();
  }
}

/// Closes the translation modal stack, closes Now Playing, and navigates to
/// the Translation section of Playback settings.
///
/// The router and provider container are captured before popping so navigation
/// still runs after the modal route leaves the tree.
void openTranslationSettings(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  final container = ProviderScope.containerOf(context, listen: false);
  closeTranslationModalStack(context);
  container.read(nowPlayingOpenProvider.notifier).close();
  router?.go(settingsFocusLocation(SettingsAnchor.playbackTranslation));
}

/// Closes the translation modal stack that contains [context] (the parent
/// modal's context, so any child picker above it closes too), closes Now
/// Playing, and navigates to the translation plugin store.
///
/// The router and provider container are captured before popping so navigation
/// still runs after the modal routes leave the tree.
void openTranslationStore(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  final container = ProviderScope.containerOf(context, listen: false);
  closeTranslationModalStack(context);
  container.read(nowPlayingOpenProvider.notifier).close();
  router?.go(translationPluginsRoute);
}
