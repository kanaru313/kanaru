import 'package:material_ui/material_ui.dart';

import 'full_or_compact_control.dart';

/// Row width below which the control is built compact (a dropdown rather
/// than a segmented button), so it leaves the title enough room.
const _compactBelow = 560.0;

/// Width every compact control gets, so their right and left edges line up
/// down the list. Fits the longest option (with its icon and arrow) in every
/// shipped language.
const _compactControlWidth = 200.0;

/// Height of every settings control (dropdowns, segmented buttons, buttons),
/// so they line up whatever their kind and the platform's density.
const settingControlHeight = 40.0;

/// Style that gives a settings button exactly [settingControlHeight], with
/// no extra tap-target margin, whatever the platform's density.
ButtonStyle settingButtonStyle() => const ButtonStyle(
  visualDensity: VisualDensity.standard,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  fixedSize: WidgetStatePropertyAll(Size.fromHeight(settingControlHeight)),
);

/// Share of the row a control may take, so the title always keeps a part.
const _controlMaxShare = 0.6;

/// A settings row: [title] with an optional [subtitle], and at its right
/// a control.
///
/// The control always stays on the title's line. A narrow row shows the
/// compact control at a fixed width shared by all rows (less only when the
/// row is very narrow); a wide row lets the full control take its own width,
/// or falls back to the compact one when the full one does not fit (long
/// labels, large text). A long title wraps to a second line.
///
/// Both kinds of row build the same widgets, so a control keeps its state
/// (a running animation, focus, an open menu) when the window is resized
/// across the threshold.
class SettingRow extends StatelessWidget {
  /// A row whose control has a full and a compact form, built by [control].
  const SettingRow({
    super.key,
    required this.title,
    required Widget Function(bool compact) control,
    this.subtitle,
  }) : _buildControl = control,
       _singleControl = null;

  /// A row whose [control] has a single form: built once, and narrowed to
  /// the compact width where a compact control would be shown.
  const SettingRow.single({
    super.key,
    required this.title,
    required Widget control,
    this.subtitle,
  }) : _buildControl = null,
       _singleControl = control;

  final String title;
  final String? subtitle;
  final Widget Function(bool compact)? _buildControl;
  final Widget? _singleControl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;

    return LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        // As tall as a one-line list tile.
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _control(constraints.maxWidth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _control(double rowWidth) {
    final build = _buildControl;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: rowWidth * _controlMaxShare),
      child: FullOrCompactControl(
        full: build == null ? _singleControl! : build(false),
        compact: build?.call(true),
        compactWidth: _compactControlWidth,
        forceCompact: rowWidth < _compactBelow,
      ),
    );
  }
}
