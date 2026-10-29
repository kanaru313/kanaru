import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/placeholder_colors.dart';
import 'folder_tree.dart';

// Geometry as fractions of the widget size.
const _tabLeft = 0.07, _tabTop = 0.06, _tabWidth = 0.38, _tabHeight = 0.12;
const _bodyLeft = 0.07, _bodyTop = 0.14, _bodyWidth = 0.86, _bodyHeight = 0.82;
const _tabExtra = 0.04; // tab runs this far under the body's top edge
const _cornerRadius = 0.08;
const _coverFraction = 0.70;

/// A folder drawn as a folder-shaped frame (primary outline, container fill)
/// holding one square cover, or a seeded music-note placeholder when the
/// folder has none. Reads only the node and the cover cache directory.
class FolderArt extends ConsumerWidget {
  const FolderArt({
    super.key,
    required this.folder,
    required this.size,
    this.direct = false,
  });

  final FolderNode folder;
  final double size;

  /// Shows the cover of the folder's own songs ([FolderNode.directCoverKey])
  /// instead of the one shown in the tree ([FolderNode.coverKey]).
  final bool direct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = placeholderColors(scheme, folder.path);
    final cover = size * _coverFraction;
    final slot = size * (_bodyTop + _bodyHeight / 2) - cover / 2;
    final key = direct ? folder.directCoverKey : folder.coverKey;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _FolderFramePainter(
                  fill: scheme.primaryContainer,
                  stroke: scheme.primary,
                  strokeWidth: (size * 0.02).clamp(1.5, 3.0),
                ),
              ),
            ),
            Positioned(
              left: (size - cover) / 2,
              top: slot,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(coverArtRadius(cover)),
                  border: Border.all(color: scheme.outlineVariant, width: 1),
                ),
                child: CoverArt(
                  path: coverPath(ref.watch(coverCacheDirectoryProvider), key),
                  size: cover,
                  placeholder: ColoredBox(
                    color: background,
                    child: Icon(
                      AppIcons.musicNoteOutlined,
                      size: cover * 0.4,
                      color: foreground,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tab and body of a folder as one outline, filled then stroked.
class _FolderFramePainter extends CustomPainter {
  const _FolderFramePainter({
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
  });

  final Color fill;
  final Color stroke;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final radius = Radius.circular(s * _cornerRadius);
    final tab = RRect.fromRectAndCorners(
      Rect.fromLTWH(
        s * _tabLeft,
        s * _tabTop,
        s * _tabWidth,
        s * (_tabHeight + _tabExtra),
      ),
      topLeft: radius,
      topRight: radius,
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        s * _bodyLeft,
        s * _bodyTop,
        s * _bodyWidth,
        s * _bodyHeight,
      ),
      radius,
    );
    final outline = Path.combine(
      PathOperation.union,
      Path()..addRRect(tab),
      Path()..addRRect(body),
    );
    canvas.drawPath(outline, Paint()..color = fill);
    canvas.drawPath(
      outline,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_FolderFramePainter old) =>
      old.fill != fill ||
      old.stroke != stroke ||
      old.strokeWidth != strokeWidth;
}
