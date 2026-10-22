import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/settings_provider.dart';
import 'playback_session_file.dart';

/// Folder of the cover thumbnails, for the session file to store cover keys
/// instead of absolute paths. `null` by default so tests never touch the
/// user's cache; `main()` overrides it with the folder the indexer writes to,
/// which does not depend on the library database opening.
final sessionCoverDirectoryProvider = Provider<String?>((ref) => null);

/// Where the playback session is kept: next to the settings file, so the app
/// uses `~/.config/kanaru/playback-session.json`, a test with a temporary
/// settings file gets a temporary session file, and a test without one keeps
/// the session in memory only.
final playbackSessionFileProvider = Provider<PlaybackSessionFile?>(
  (ref) => playbackSessionFileFor(
    ref.watch(settingsFileProvider),
    coverDirectory: ref.watch(sessionCoverDirectoryProvider),
  ),
);
