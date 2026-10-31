import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/lyrics_plugins/plugin_record_text.dart';
import 'plugin_icon.dart';
import 'plugin_source_text.dart';

/// Name shown for the built-in source.
const lrclibDisplayName = 'LRCLIB';

/// Address the built-in source connects to.
const _lrclibHost = 'lrclib.net';

/// One line of the source list: drag handle, icon, name with its subline and
/// the switch. A plugin row opens the plugin's page on tap ([onOpen]); the
/// built-in row has none.
///
/// The handle starts a drag at once ([index] is the row's place in the list).
/// With the keyboard, Alt + Up or Down on the focused handle calls [onMove]
/// with -1 or 1.
class LyricsSourceRow extends StatelessWidget {
  const LyricsSourceRow({
    super.key,
    required this.entry,
    required this.index,
    this.canReorder = true,
    required this.onToggle,
    required this.onMove,
    this.onOpen,
  });

  final LyricsSourceEntry entry;
  final int index;

  /// False while nothing can be written: the handle is drawn but does nothing.
  final bool canReorder;

  /// Null while switches cannot be written (no library database).
  final ValueChanged<bool>? onToggle;
  final ValueChanged<int> onMove;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final record = entry.record;
    final name = record?.name ?? lrclibDisplayName;
    final lines = record == null
        ? [l10n.lyricsSourceBuiltInHosts(_lrclibHost)]
        : [
            '${pluginByline(l10n, record)} · ${pluginSourceText(l10n, record)}',
            record.hosts.join(', '),
          ];
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return InkWell(
      onTap: onOpen,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _DragHandle(index: index, onMove: onMove, enabled: canReorder),
              const SizedBox(width: 4),
              PluginIcon(record: record, fallback: AppIcons.lyrics),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        if (record == null) ...[
                          const SizedBox(width: 8),
                          _Badge(l10n.lyricsSourceBuiltIn),
                        ],
                      ],
                    ),
                    for (final line in lines)
                      if (line.isNotEmpty)
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: name,
                child: Switch(value: entry.enabled, onChanged: onToggle),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

/// The grip at the row's left. Flutter's list adds the "move up / down /
/// to start / to end" screen reader actions to the row; this adds the
/// keyboard path.
class _DragHandle extends StatelessWidget {
  const _DragHandle({
    required this.index,
    required this.onMove,
    required this.enabled,
  });

  final int index;
  final ValueChanged<int> onMove;
  final bool enabled;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      onMove(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      onMove(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (!enabled) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(AppIcons.dragHandle, color: colors.outlineVariant),
      );
    }
    return Tooltip(
      message: context.l10n.lyricsSourceDragHandle,
      child: Focus(
        onKeyEvent: _onKey,
        child: Builder(
          builder: (context) => ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Focus.of(context).hasFocus
                      ? Border.all(color: colors.primary, width: 2)
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    AppIcons.dragHandle,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
