import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/l10n.dart';
import '../../../../shared/settings_routes.dart';
import '../../../../shared/translation_plugin_routes.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../now_playing/now_playing_open_provider.dart';

/// Shows an info snackbar when the user tries to turn lyrics translation on
/// while no translation service is selected.
///
/// With [hasPlugins] false, it guides the user to the plugin store on the
/// Translate chip; with [hasPlugins] true, it guides them to the Translation
/// section of Playback settings.
void showTranslationServiceMissingSnackBar(
  BuildContext context, {
  required bool hasPlugins,
}) {
  final l10n = context.l10n;
  final router = GoRouter.maybeOf(context);
  final container = ProviderScope.containerOf(context);
  final route = hasPlugins
      ? settingsFocusLocation(SettingsAnchor.playbackTranslation)
      : translationPluginsRoute;

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      appSnackBar(
        kind: AppSnackBarKind.info,
        title: hasPlugins
            ? l10n.lyricsTranslationChooseServiceFirst
            : l10n.lyricsTranslationNeedsPlugin,
        persist: false,
        action: SnackBarAction(
          label: hasPlugins
              ? l10n.lyricsTranslationChooseService
              : l10n.lyricsTranslationOpenPluginStore,
          onPressed: () {
            container.read(nowPlayingOpenProvider.notifier).close();
            router?.go(route);
          },
        ),
      ),
    );
}
