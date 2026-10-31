import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugin_record.dart';
import '../../core/lyrics/plugins/plugin_log_paths.dart';
import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import '../../core/lyrics/plugins/store/lyrics_plugin_dirs.dart';

/// The icon of the plugin installed as [record]: its package's `icon.png`, or
/// null when the data folder is unknown or the folder name is not a legal one.
String? installedIconPath(String? dataDirectory, LyricsPluginRecord record) {
  if (dataDirectory == null) return null;
  try {
    final dir = LyricsPluginDirs(dataDirectory).resolve(record.packageDir);
    return '${dir.path}/icon.png';
  } on ArgumentError {
    return null;
  }
}

/// The icon of a store row: the installed package's icon, else the catalog
/// icon (fetched once through the icon cache), else a plain extension icon.
/// A missing or broken icon is never an error.
class StoreRowIcon extends ConsumerStatefulWidget {
  const StoreRowIcon({super.key, required this.row, this.repo, this.size = 40});

  final StoreRow row;

  /// The repository of a row that is not installed, for its catalog icon.
  final PluginRepo? repo;
  final double size;

  @override
  ConsumerState<StoreRowIcon> createState() => _StoreRowIconState();
}

class _StoreRowIconState extends ConsumerState<StoreRowIcon> {
  Future<Uint8List?>? _catalogIcon;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StoreRowIcon old) {
    super.didUpdateWidget(old);
    if (old.row.entry != widget.row.entry || old.repo != widget.repo) _load();
  }

  void _load() {
    final repo = widget.repo;
    final entry = widget.row.entry;
    _catalogIcon = widget.row.record != null || repo == null || entry == null
        ? null
        : ref
              .read(repoIconCacheProvider)
              .iconOf(repo, entry)
              .onError(
                // A failed icon is a missing icon.
                (_, _) => null,
              );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = widget.size;
    final placeholder = ColoredBox(
      color: colors.secondaryContainer,
      child: Icon(
        Icons.extension_outlined,
        size: size * 0.55,
        color: colors.onSecondaryContainer,
      ),
    );
    final record = widget.row.record;
    final path = record == null
        ? null
        : installedIconPath(
            ref.watch(lyricsPluginDataDirectoryProvider),
            record,
          );
    final decode = (size * MediaQuery.devicePixelRatioOf(context)).round();
    Widget image(ImageProvider provider) => Image(
      image: ResizeImage(provider, width: decode, height: decode),
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => placeholder,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: path != null
            ? image(FileImage(File(path)))
            : FutureBuilder<Uint8List?>(
                future: _catalogIcon,
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  return bytes == null
                      ? placeholder
                      : image(MemoryImage(bytes));
                },
              ),
      ),
    );
  }
}
