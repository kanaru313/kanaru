import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/lyrics_plugin_spec.dart';
import '../../core/lyrics/plugins/plugin_needs_config_notices.dart';
import '../../features/player/now_playing/now_playing_open_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/lyrics_source_routes.dart';
import '../../shared/translation_plugin_routes.dart';
import '../../shared/widgets/app_snack_bar.dart';

/// Wraps the shell and shows a floating snack bar for every needs-config
/// report (a blocked run, or the user switching on or picking a plugin that
/// lacks a required setting). A new report replaces the previous needs-config
/// notice; it never closes another feature's snack bar (it queues behind it),
/// and at most one of its own waits in that queue. "Open config" closes Now
/// Playing and opens the plugin's page.
class PluginNeedsConfigNoticeHost extends ConsumerStatefulWidget {
  const PluginNeedsConfigNoticeHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PluginNeedsConfigNoticeHost> createState() =>
      _PluginNeedsConfigNoticeHostState();
}

class _PluginNeedsConfigNoticeHostState
    extends ConsumerState<PluginNeedsConfigNoticeHost> {
  /// The last snack bar of this widget, until it is gone.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _shown;

  /// [_shown] finished appearing, so it is the messenger's current snack
  /// bar and may be closed; before that it waits behind another message.
  bool _visible = false;

  void _show(PluginNeedsConfigNotice notice) {
    final shown = _shown;
    if (shown != null) {
      // Not on screen yet (behind another message, or still sliding in): one
      // pending notice is enough.
      if (!_visible) return;
      // Closing is only valid for the current snack bar, which ours is.
      shown.close();
    }
    final l10n = context.l10n;
    // Taken now: the notice may be gone by the time the action is tapped.
    final router = GoRouter.maybeOf(context);
    final container = ProviderScope.containerOf(context);
    final route = notice.kind == PluginKind.translate
        ? translationPluginRoute(notice.installId)
        : lyricsPluginRoute(notice.installId);
    _visible = false;
    late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
    controller;
    controller = ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        kind: AppSnackBarKind.warning,
        title: l10n.pluginNeedsConfigTitle(notice.name),
        duration: const Duration(seconds: 8),
        onVisible: () {
          if (identical(_shown, controller)) _visible = true;
        },
        action: SnackBarAction(
          label: l10n.pluginOpenConfig,
          onPressed: () {
            container.read(nowPlayingOpenProvider.notifier).close();
            router?.go(route);
          },
        ),
      ),
    );
    _shown = controller;
    controller.closed.then((_) {
      if (identical(_shown, controller)) {
        _shown = null;
        _visible = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pluginNeedsConfigNoticesProvider, (previous, next) {
      if (next != null) _show(next);
    });
    return widget.child;
  }
}
