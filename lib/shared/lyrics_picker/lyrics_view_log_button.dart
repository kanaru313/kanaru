import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/lyrics_plugin_spec.dart' show lrclibSourceId;
import '../../core/lyrics/plugins/plugin_log_paths.dart';
import '../../l10n/l10n.dart';
import '../show_in_file_manager.dart';
import '../widgets/app_snack_bar.dart';

/// The log file of lyrics source [providerId], or `null` when there is
/// nothing to show: LRCLIB, an id that is no plugin, no log folder on this
/// system, or a plugin that has not logged anything yet.
File? lyricsPluginLogToShow(Directory? logDir, String? providerId) {
  if (logDir == null || providerId == null || providerId == lrclibSourceId) {
    return null;
  }
  final file = lyricsPluginLogFile(logDir, providerId);
  if (file == null) return null;
  try {
    return file.existsSync() ? file : null;
  } on FileSystemException {
    return null;
  }
}

/// "View log": shows the log file of plugin source [providerId] in the file
/// manager. It takes no room (an empty box) for LRCLIB and for a plugin
/// without a log file, so a failure line offers it only when it leads
/// somewhere.
class LyricsViewLogButton extends ConsumerWidget {
  const LyricsViewLogButton({super.key, required this.providerId});

  final String? providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = lyricsPluginLogToShow(
      ref.watch(lyricsPluginLogDirProvider),
      providerId,
    );
    if (file == null) return const SizedBox.shrink();
    return TextButton(
      onPressed: () async {
        // Taken before the await: leaving meanwhile must not throw.
        final messenger = ScaffoldMessenger.maybeOf(context);
        final failed = context.l10n.settingsOpenFailed(file.path);
        if (await ref.read(showInFileManagerProvider)(file.path)) return;
        messenger?.showSnackBar(
          appSnackBar(kind: AppSnackBarKind.error, title: failed),
        );
      },
      child: Text(context.l10n.lyricsViewLog),
    );
  }
}
