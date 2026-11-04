import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';

const fontPreviewSampleText = 'Aa Bb Cc Gg Qq Rr Yy 0123456789';
const kFontPreviewHeight = 56.0;

class FontCatalogTile extends StatelessWidget {
  const FontCatalogTile({
    super.key,
    required this.id,
    required this.label,
    this.previewSvgAsset,
    this.family,
    this.formattedSize,
    required this.isSelected,
    required this.isInstalled,
    required this.isDownloading,
    this.downloadProgress,
    this.canDelete = false,
    required this.onSelect,
    this.onDownload,
    this.onDelete,
  });

  final String id;
  final String label;
  final String? previewSvgAsset;
  final String? family; // used to render the fallback preview with the real font
  final String? formattedSize;
  final bool isSelected;
  final bool isInstalled;
  final bool isDownloading;
  final double? downloadProgress; // null while downloading = indeterminate
  final bool canDelete;
  final VoidCallback onSelect;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final titleColor = isSelected ? colors.primary : colors.onSurface;

    final Widget preview;
    if (previewSvgAsset != null) {
      // The SVG already contains the font name and the sample line, drawn
      // with the font's own outlines. No separate text label.
      preview = SizedBox(
        height: kFontPreviewHeight,
        child: SvgPicture.asset(
          previewSvgAsset!,
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          semanticsLabel: label,
          colorFilter: ColorFilter.mode(titleColor, BlendMode.srcIn),
        ),
      );
    } else {
      preview = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: isInstalled ? family : null,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fontPreviewSampleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: isInstalled ? family : null,
              color: colors.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      );
    }

    final Widget trailing;
    if (isSelected) {
      trailing = Icon(
        AppIcons.check,
        color: colors.primary,
        semanticLabel: l10n.selectedFontSemantics,
      );
    } else if (isDownloading) {
      trailing = SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5, value: downloadProgress),
      );
    } else if (!isInstalled) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (formattedSize != null) ...[
            Text(
              formattedSize!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(AppIcons.arrowDownload),
            tooltip: l10n.downloadFontTooltip(formattedSize ?? ''),
            onPressed: onDownload,
          ),
        ],
      );
    } else if (canDelete && onDelete != null) {
      trailing = IconButton(
        icon: const Icon(AppIcons.deleteOutline),
        tooltip: l10n.deleteFontTooltip,
        onPressed: onDelete,
      );
    } else {
      trailing = const SizedBox.shrink();
    }

    return InkWell(
      // Only installed rows react to a tap; a stray tap never starts a download.
      onTap: isInstalled ? onSelect : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(child: preview),
            const SizedBox(width: 16),
            trailing,
          ],
        ),
      ),
    );
  }
}
