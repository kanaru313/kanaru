import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/settings_provider.dart';
import 'playback_session_file.dart';

/// Where the playback session is kept: next to the settings file, so the app
/// uses `~/.config/kanaru/playback-session.json`, a test with a temporary
/// settings file gets a temporary session file, and a test without one keeps
/// the session in memory only.
final playbackSessionFileProvider = Provider<PlaybackSessionFile?>(
  (ref) => playbackSessionFileFor(ref.watch(settingsFileProvider)),
);
