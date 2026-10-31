import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugins_provider.dart';
import '../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/lyrics_source_routes.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'lyrics_source_row.dart';
import 'lyrics_sources_header.dart';
import 'lyrics_sources_menu.dart';
import 'plugin_config_save.dart';

final _log = Logger('lyrics_sources');

/// The lyrics sources page: LRCLIB and the installed plugins in one list the
/// user reorders (drag, or Alt + arrows on a handle) and switches on or off.
/// A plugin row opens the plugin's page.
class LyricsSourcesPage extends ConsumerStatefulWidget {
  const LyricsSourcesPage({super.key});

  @override
  ConsumerState<LyricsSourcesPage> createState() => _LyricsSourcesPageState();
}

class _LyricsSourcesPageState extends ConsumerState<LyricsSourcesPage> {
  /// The order just chosen, shown until the database answers with it, so a
  /// dropped row does not jump back for a moment.
  List<String>? _chosen;

  List<String> _ids(List<LyricsSourceEntry> entries) => [
    for (final e in entries) e.id,
  ];

  List<LyricsSourceEntry> _shown(List<LyricsSourceEntry> entries) {
    final chosen = _chosen;
    if (chosen == null) return entries;
    final byId = {for (final e in entries) e.id: e};
    // A plugin came or went meanwhile: the saved order wins.
    if (chosen.length != byId.length || !chosen.every(byId.containsKey)) {
      return entries;
    }
    return [for (final id in chosen) byId[id]!];
  }

  /// Counts the saves, so a late answer about an older one changes nothing.
  int _latest = 0;
  Timer? _settle;

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  Future<void> _apply(List<String> order) async {
    final controller = ref.read(lyricsPluginsControllerProvider);
    if (controller == null) return;
    final mine = ++_latest;
    setState(() => _chosen = order);
    try {
      // Plugins removed meanwhile come back as skipped; the list already
      // follows the database, so there is nothing to tell the user.
      await controller.reorder(order);
    } catch (error, stackTrace) {
      _log.warning('Saving the source order failed', error, stackTrace);
      if (mounted && mine == _latest) setState(() => _chosen = null);
      return;
    }
    if (!mounted) return;
    // The database may answer with another order (a skipped plugin). Its
    // stream needs a moment to say so, so the chosen order is dropped after a
    // pause if the stream never confirmed it.
    _settle?.cancel();
    _settle = Timer(const Duration(seconds: 1), () {
      if (!mounted || mine != _latest) return;
      final saved = _ids(ref.read(lyricsSourcesProvider));
      if (_chosen != null && !listEquals(saved, _chosen)) {
        setState(() => _chosen = null);
      }
    });
  }

  void _reorder(List<LyricsSourceEntry> shown, int from, int to) {
    final order = _ids(shown);
    if (to == from) return;
    order.insert(to, order.removeAt(from));
    unawaited(_apply(order));
  }

  void _move(List<LyricsSourceEntry> shown, int from, int delta) {
    final to = from + delta;
    if (to < 0 || to >= shown.length) return;
    final order = _ids(shown);
    order.insert(to, order.removeAt(from));
    unawaited(_apply(order));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = ref.watch(lyricsSourcesProvider);
    ref.listen(lyricsSourcesProvider, (_, next) {
      if (_chosen != null && listEquals(_ids(next), _chosen)) {
        setState(() => _chosen = null);
      }
    });
    final shown = _shown(entries);
    final controller = ref.watch(lyricsPluginsControllerProvider);
    return PageScaffold(
      title: l10n.lyricsSourcesTitle,
      actions: const [LyricsSourcesMenu()],
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            buildDefaultDragHandles: false,
            header: const LyricsSourcesHeader(),
            footer: shown.any((e) => e.record != null)
                ? null
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.lyricsSourcesEmptyHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
            itemCount: shown.length,
            onReorderItem: (from, to) => _reorder(shown, from, to),
            itemBuilder: (context, index) {
              final entry = shown[index];
              return LyricsSourceRow(
                key: ValueKey(entry.id),
                entry: entry,
                index: index,
                canReorder: controller != null,
                onToggle: controller == null
                    ? null
                    // A plugin removed meanwhile answers skipped; the row is
                    // already gone from the list, so nothing is shown.
                    : (on) => unawaited(
                        setLyricsSourceOn(controller, entry.id, on),
                      ),
                onMove: (delta) => _move(shown, index, delta),
                onOpen: entry.record == null
                    ? null
                    : () => context.go(lyricsPluginRoute(entry.id)),
              );
            },
          ),
        ),
      ),
    );
  }
}
