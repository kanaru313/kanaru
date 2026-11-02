import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/placeholder_colors.dart';
import 'folder_tree.dart';

// Geometry as fractions of the widget size for the folder backplate.
const _tabLeft = 0.0, _tabTop = 0.0, _tabWidth = 0.44, _tabHeight = 0.16;
const _bodyLeft = 0.0, _bodyTop = 0.08, _bodyWidth = 0.90, _bodyHeight = 0.88;
const _tabExtra = 0.04;
const _cornerRadius = 0.09;
const _coverFraction = 0.88;

/// A folder drawn as a layered card: a folder tab and backplate in the background,
/// and an offset prominent square cover in the foreground with shadow.
/// Reads only the node and the cover cache directory.
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
    final key = direct ? folder.directCoverKey : folder.coverKey;
    final radius = size < 64 ? 6.0 : (cover * 0.10).clamp(8.0, 18.0);
    final folderFill = scheme.brightness == Brightness.dark
        ? Color.lerp(
            scheme.surfaceContainerHigh,
            scheme.primaryContainer,
            0.45,
          )!
        : Color.lerp(
            scheme.primaryContainer,
            scheme.surfaceContainerHighest,
            0.35,
          )!;

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _FolderFramePainter(
                  fill: folderFill,
                  stroke: scheme.primary,
                  strokeWidth: (size * 0.015).clamp(1.0, 2.5),
                  isDark: scheme.brightness == Brightness.dark,
                ),
              ),
            ),
            Positioned(
              left: size - cover,
              top: size - cover,
              width: cover,
              height: cover,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.28),
                      blurRadius: (cover * 0.06).clamp(3.0, 14.0),
                      offset: Offset(-cover * 0.01, cover * 0.02),
                    ),
                  ],
                ),
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: scheme.outlineVariant, width: 1),
                  ),
                  child: CoverArt(
                    path: coverPath(
                      ref.watch(coverCacheDirectoryProvider),
                      key,
                    ),
                    size: cover,
                    radius: radius,
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
            ),
          ],
        ),
      ),
    );
  }
}

/// The tab and back body of the folder painted with subtle depth.
class _FolderFramePainter extends CustomPainter {
  const _FolderFramePainter({
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
    required this.isDark,
  });

  final Color fill;
  final Color stroke;
  final double strokeWidth;
  final bool isDark;

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
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(
        s * _bodyLeft,
        s * _bodyTop,
        s * _bodyWidth,
        s * _bodyHeight,
      ),
      topLeft: radius,
      topRight: radius,
      bottomLeft: radius,
      bottomRight: Radius.circular(s * 0.04),
    );
    final outline = Path.combine(
      PathOperation.union,
      Path()..addRRect(tab),
      Path()..addRRect(body),
    );

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(fill, Colors.white, isDark ? 0.09 : 0.05)!, fill],
      ).createShader(Rect.fromLTWH(0, 0, s, s));

    canvas.drawPath(outline, fillPaint);
    canvas.drawPath(
      outline,
      Paint()
        ..color = stroke.withValues(alpha: isDark ? 0.22 : 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_FolderFramePainter old) =>
      old.fill != fill ||
      old.stroke != stroke ||
      old.strokeWidth != strokeWidth ||
      old.isDark != isDark;
}
