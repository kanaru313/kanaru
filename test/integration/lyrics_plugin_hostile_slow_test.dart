@Tags(['native'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';

import 'hostile_case_support.dart';
import 'native_plugin_env.dart';

// The hostile plugins that only the runtime's 15 s wall-time limit stops. A
// timeout is a network failure for the app. Kept apart from the quick cases so
// the files run in parallel.
void main() {
  setUpAll(initNativeLibrary);

  group('hostile plugin stopped by the time limit', () {
    hostileCaseTest(
      const HostileCase(
        'infinite_loop',
        LyricsFetchKind.network,
        console: ['before the loop'],
      ),
    );
    hostileCaseTest(
      const HostileCase(
        'redos',
        LyricsFetchKind.network,
        console: ['before the regex'],
      ),
    );
  });
}
