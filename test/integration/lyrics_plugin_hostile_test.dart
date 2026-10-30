@Tags(['native'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';

import 'hostile_case_support.dart';
import 'native_plugin_env.dart';

// Plugins that misbehave (test/fixtures/lyrics_plugins/hostile) run on the
// real native runtime. Each must end as the documented failure, store nothing
// as "no lyrics", leave one event in its own log and one INFO line in the app
// log. Endless loops and regex bombs, which need the 15 s wall-time limit,
// are in lyrics_plugin_hostile_slow_test.dart so the two files run in
// parallel.
void main() {
  setUpAll(initNativeLibrary);

  group('hostile plugin', () {
    hostileCaseTest(
      const HostileCase(
        'big_allocation',
        LyricsFetchKind.invalidResponse,
        console: ['before the allocation'],
      ),
    );
    hostileCaseTest(
      const HostileCase(
        'deep_recursion',
        LyricsFetchKind.invalidResponse,
        console: ['before the recursion'],
      ),
    );
    hostileCaseTest(
      HostileCase(
        'eleven_fetches',
        LyricsFetchKind.invalidResponse,
        console: [for (var i = 0; i < 11; i++) 'fetch $i'],
        requests: List.filled(10, 'lrclib.net /api/search 200'),
      ),
    );
    hostileCaseTest(
      const HostileCase(
        'undeclared_host',
        LyricsFetchKind.blockedHost,
        configValue: 'sekret-value-123',
        console: ['before the fetch, token ***'],
        requests: ['evil.example.com /steal/*** null'],
        appLogHost: 'evil.example.com',
      ),
    );
    hostileCaseTest(
      const HostileCase(
        'plain_http',
        LyricsFetchKind.blockedHost,
        console: ['before the fetch'],
        requests: ['lrclib.net /api/search null'],
        appLogHost: 'lrclib.net',
      ),
    );
    hostileCaseTest(
      const HostileCase(
        'swallowed_network_error',
        LyricsFetchKind.network,
        console: ['fetch failed: NetworkError'],
        requests: ['lrclib.net /down null'],
      ),
    );
    hostileCaseTest(
      const HostileCase(
        'wrong_output_shape',
        LyricsFetchKind.invalidResponse,
        console: ['before the answer'],
        message: 'search output must be an array',
      ),
    );
    hostileCaseTest(
      const HostileCase(
        'huge_output',
        LyricsFetchKind.invalidResponse,
        console: ['before the answer'],
      ),
    );
    // An error the script throws (here the one load() throws) is a bug of
    // the plugin, so `invalidResponse`, as docs/lyrics-plugin-api.md (Errors)
    // says.
    hostileCaseTest(
      const HostileCase(
        'load_outside_package',
        LyricsFetchKind.invalidResponse,
        console: ['before the load'],
        message: 'load',
      ),
    );
    consoleSpamTest('console_spam');
  });
}
