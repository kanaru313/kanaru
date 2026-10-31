import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugin_record.dart';
import '../../core/lyrics/plugins/plugin_log_paths.dart';
import '../../core/lyrics/plugins/store/lyrics_plugin_dirs.dart';
import '../../shared/widgets/cover_art.dart' show coverDecodeWidth;
import '../../shared/icons/app_icons.dart';

/// The icon of a plugin that has none of its own.
const pluginDefaultIcon = AppIcons.extension;

/// The `icon.png` of an installed plugin, or null when the data folder is
/// unknown or the package folder name is not a legal one.
String? pluginIconPath(String? dataDirectory, LyricsPluginRecord record) {
  if (dataDirectory == null) return null;
  try {
    final dir = LyricsPluginDirs(dataDirectory).resolve(record.packageDir);
    return '${dir.path}/icon.png';
  } on ArgumentError {
    return null;
  }
}

/// A square icon: the plugin's `icon.png` when it has one that can be shown,
/// else [fallback] (the default plugin icon). The picture is decoded at the
/// display size, never at the size of the file, so a large icon costs no more
/// memory than a small one.
class PluginIcon extends ConsumerWidget {
  const PluginIcon({
    super.key,
    required this.record,
    this.size = 40,
    this.fallback = pluginDefaultIcon,
  });

  /// The plugin; null draws [fallback] (used for the built-in source).
  final LyricsPluginRecord? record;
  final double size;
  final IconData fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.secondaryContainer,
      child: Icon(
        fallback,
        size: size * 0.55,
        color: colors.onSecondaryContainer,
      ),
    );
    final path = record == null
        ? null
        : pluginIconPath(ref.watch(lyricsPluginDataDirectoryProvider), record!);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decode = coverDecodeWidth(size * dpr);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: path == null
            ? placeholder
            : Image.file(
                File(path),
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: decode,
                cacheHeight: decode,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
