import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/open_external.dart';

/// Opens an `https://` address in the desktop's default app. Returns `false`
/// when nothing could open it, or when the address is not `https://`.
/// Swapped out in tests.
final lyricsSourcesOpenUrlProvider =
    Provider<Future<bool> Function(String url)>(
      (ref) =>
          (url) async => url.startsWith('https://') && await openExternal(url),
    );
