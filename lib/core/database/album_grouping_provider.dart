import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_provider.dart';

/// How albums are grouped now, from the settings.
final albumGroupingProvider = Provider<AlbumGrouping>(
  (ref) =>
      ref.watch(settingsProvider.select((s) => s.libraryScan.albumGrouping)),
);
