import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'separator_page_dots.dart';

/// Entries shown on one page of a separator list.
const separatorPageSize = 8;

const _minRowHeight = 36.0;

/// Height of one entry row: the text line (about 20 px at the normal size)
/// plus its padding, grown with the text scale so a large font is not cut.
double separatorRowHeight(BuildContext context) =>
    math.max(_minRowHeight, MediaQuery.textScalerOf(context).scale(20) + 16);

/// The entries of a separator list, [separatorPageSize] to a page. A longer
/// list is swiped in horizontal pages with pagination dots below, never
/// scrolled down; the list area keeps one height whatever the page, so the
/// dialog around it does not jump. The page follows the list: a new entry
/// (added last) opens the last page, and removing the last entry of the last
/// page steps back one.
class SeparatorListPages extends StatefulWidget {
  const SeparatorListPages({
    super.key,
    required this.entries,
    required this.emptyText,
    required this.onRemove,
  });

  final List<String> entries;

  /// Shown in place of an empty list.
  final String emptyText;
  final ValueChanged<String> onRemove;

  @override
  State<SeparatorListPages> createState() => _SeparatorListPagesState();
}

class _SeparatorListPagesState extends State<SeparatorListPages> {
  final _controller = PageController();
  int _page = 0;

  int _pageCount(int entries) =>
      math.max(1, (entries / separatorPageSize).ceil());

  @override
  void didUpdateWidget(SeparatorListPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a change of the list moves the page, not every parent rebuild.
    if (listEquals(widget.entries, oldWidget.entries)) return;
    final last = _pageCount(widget.entries.length) - 1;
    final grew = widget.entries.length > oldWidget.entries.length;
    final target = grew ? last : math.min(_page, last);
    _follow(target);
  }

  /// Opens page [target] once this frame has laid out the new page count.
  void _follow(int target) {
    _page = target;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (_controller.page?.round() == target) return;
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutQuart,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final pages = _pageCount(entries.length);
    final rowHeight = separatorRowHeight(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: separatorPageSize * rowHeight,
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    widget.emptyText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : PageView.builder(
                  controller: _controller,
                  itemCount: pages,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, page) => Column(
                    children: [
                      for (final entry
                          in entries
                              .skip(page * separatorPageSize)
                              .take(separatorPageSize))
                        _EntryRow(
                          key: ValueKey(entry),
                          entry: entry,
                          height: rowHeight,
                          onRemove: () => widget.onRemove(entry),
                        ),
                    ],
                  ),
                ),
        ),
        // Reserved even with one page, so the dialog keeps its height.
        SizedBox(
          height: 26,
          child: pages > 1
              ? SeparatorPageDots(
                  count: pages,
                  selected: _page,
                  onSelect: (page) => _controller.animateToPage(
                    page,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutQuart,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

/// One entry in monospace, so symbols such as `;` and `/` read clearly, and
/// the button that removes it.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    super.key,
    required this.entry,
    required this.height,
    required this.onRemove,
  });

  final String entry;
  final double height;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontFamilyFallback: const [
                        'Noto Sans Mono',
                        'DejaVu Sans Mono',
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.separatorsRemove(entry),
                  icon: const Icon(AppIcons.close, size: 18),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(32),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
