import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Row width below which the control is built compact (a dropdown rather
/// than a segmented button), so it leaves the title enough room.
const _compactBelow = 560.0;

/// Width every compact control gets, so their right and left edges line up
/// down the list. Fits the longest option (with its icon and arrow) in every
/// shipped language.
const _compactControlWidth = 200.0;

/// Share of the row a control may take, so the title always keeps a part.
const _controlMaxShare = 0.6;

/// A settings row: [title] with an optional [subtitle], and at its right the
/// control built by [control].
///
/// The control always stays on the title's line. A narrow row asks for a
/// compact control and gives it a fixed width shared by all rows (less only
/// when the row is very narrow); a wide row lets the full control take its
/// own width, shrunk if it is still too wide. A long title wraps to a second
/// line.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    required this.control,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget Function(bool compact) control;

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
    final maxWidth = rowWidth * _controlMaxShare;
    if (rowWidth < _compactBelow) {
      return SizedBox(
        width: math.min(_compactControlWidth, maxWidth),
        child: control(true),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: control(false),
      ),
    );
  }
}
