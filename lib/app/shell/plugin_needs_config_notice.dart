import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/lyrics_plugin_spec.dart';
import '../../core/lyrics/plugins/plugin_needs_config_notices.dart';
import '../../core/lyrics_translation/translation_service_needs_config_watch.dart';
import '../../features/player/now_playing/now_playing_open_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/lyrics_source_routes.dart';
import '../../shared/online_routes.dart';
import '../../shared/settings_routes.dart';
import '../../shared/translation_plugin_routes.dart';
import '../../shared/widgets/app_snack_bar.dart';

/// One plugin named in the notice.
typedef _Entry = ({String installId, String name, PluginKind? kind});

/// Wraps the shell and shows a floating snack bar for every needs-config
/// report (a blocked run, or the user switching on or picking a plugin that
/// lacks a required setting). Reports for different plugins while the notice
/// is pending or on screen merge into one notice that lists the names, and a
/// repeat for a listed plugin only refreshes it. It never closes another
/// feature's snack bar (it queues behind it). "Open config" closes Now Playing
/// and opens the plugin's page, or the lyrics sources / translation settings
/// when several plugins are listed.
class PluginNeedsConfigNoticeHost extends ConsumerStatefulWidget {
  const PluginNeedsConfigNoticeHost({
    super.key,
    required this.child,
    this.now = DateTime.now,
  });

  final Widget child;

  /// The clock; tests replace it (the test binding does not move
  /// `DateTime.now`).
  final DateTime Function() now;

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

  /// Plugins of the current notice (installId -> entry, insertion order);
  /// empty while no notice of ours is pending or visible.
  final Map<String, _Entry> _entries = {};

  /// What the pending snack bar shows. The messenger cannot drop a queued bar,
  /// so a report that arrives meanwhile updates this and the bar reads it.
  ValueNotifier<List<_Entry>>? _live;

  /// When [_shown] was queued.
  DateTime _queuedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// A queued bar that is still not visible after this long is taken as lost.
  static const _lostAfter = Duration(seconds: 30);

  void _show(PluginNeedsConfigNotice notice) {
    _entries[notice.installId] = (
      installId: notice.installId,
      name: notice.name,
      kind: notice.kind,
    );
    var shown = _shown;
    if (shown != null &&
        !_visible &&
        widget.now().difference(_queuedAt) > _lostAfter) {
      // A messenger clear drops a queued bar without closing it, so `closed`
      // never fires: forget it (the bar owns its notifier and disposes it when
      // it closes, if it ever appears) and show a fresh bar with the merged
      // list.
      _live = null;
      _shown = null;
      shown = null;
    }
    if (shown != null) {
      if (!_visible) {
        // Pending (behind another message or sliding in): its content
        // follows the list.
        _live?.value = List.of(_entries.values);
        return;
      }
      // Closing is only valid for the current snack bar, which ours is.
      shown.close();
    }
    // Taken now: the action may run after this widget is disposed.
    final l10n = context.l10n;
    final router = GoRouter.maybeOf(context);
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final live = ValueNotifier<List<_Entry>>(List.of(_entries.values));
    _live = live;
    _queuedAt = widget.now();
    _visible = false;
    late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
    controller;
    controller = messenger.showSnackBar(
      SnackBar(
        content: ValueListenableBuilder<List<_Entry>>(
          valueListenable: live,
          builder: (_, entries, _) => AppSnackBarContent(
            kind: AppSnackBarKind.warning,
            title: _title(l10n, [for (final e in entries) e.name]),
          ),
        ),
        duration: const Duration(seconds: 8),
        // An action makes a snack bar persistent by default.
        persist: false,
        onVisible: () {
          if (identical(_shown, controller)) {
            _visible = true;
          } else {
            // A forgotten bar that surfaced late: it is the current bar now,
            // so close it instead of leaving it next to the fresh one.
            controller.close();
          }
        },
        action: SnackBarAction(
          label: l10n.pluginOpenConfig,
          onPressed: () {
            container.read(nowPlayingOpenProvider.notifier).close();
            router?.go(_route(live.value));
          },
        ),
      ),
    );
    _shown = controller;
    controller.closed.then((_) {
      // Each bar owns its notifier.
      live.dispose();
      if (identical(_shown, controller)) {
        _shown = null;
        _visible = false;
        _live = null;
        _entries.clear();
      }
    });
  }

  @override
  void dispose() {
    // The bar disposes its own notifier when it closes.
    _live = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the translation-service watcher alive.
    ref.watch(translationServiceNeedsConfigWatchProvider);
    ref.listen(pluginNeedsConfigNoticesProvider, (previous, next) {
      if (next != null) _show(next);
    });
    return widget.child;
  }
}

/// The notice text: one name, two names, or two names and a count.
String _title(AppLocalizations l10n, List<String> names) => switch (names) {
  [final one] => l10n.pluginNeedsConfigTitle(one),
  [final a, final b] => l10n.pluginsNeedConfigTitleTwo(a, b),
  _ => l10n.pluginsNeedConfigTitleMany(names[0], names[1], names.length - 2),
};

/// Where "Open config" goes: the plugin's own page for one plugin; for
/// several, translation settings when all are translate plugins, the Online
/// page when all are source plugins, else the lyrics sources page.
String _route(List<_Entry> entries) {
  if (entries.length == 1) {
    final e = entries.single;
    return switch (e.kind) {
      PluginKind.translate => translationPluginRoute(e.installId),
      PluginKind.source => onlineSourcePluginRoute(e.installId),
      _ => lyricsPluginRoute(e.installId),
    };
  }
  if (entries.every((e) => e.kind == PluginKind.translate)) {
    return settingsFocusLocation(SettingsAnchor.playbackTranslation);
  }
  if (entries.every((e) => e.kind == PluginKind.source)) return onlineRoute;
  return lyricsSourcesRoute;
}
