import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

// The plugin imports below make a cycle with this file; accepted because the
// providers must stay importable from here, where features and tests find them.
import '../plugins/lyrics_sources_provider.dart';
import '../plugins/plugin_lyrics_provider.dart';
import '../plugins/plugin_script_runner_provider.dart';
import 'lrclib_provider.dart';
import 'lyrics_provider.dart';

final _log = Logger('lyrics_sources');

final _idPattern = RegExp(r'^[a-z0-9_-]+$');
final _hostPattern = RegExp(r'^[a-z0-9.-]+$');
const _localSuffixes = [
  '.localhost',
  '.local',
  '.internal',
  '.lan',
  '.home.arpa',
  '.localdomain',
];

/// Why [host] may not be a provider host, or `null` when it may. Only a
/// public DNS name passes: no scheme, port or path, no IP literal (so no
/// loopback, link-local or private address), no single-label or local name.
String? lyricsHostProblem(String host) {
  if (!_hostPattern.hasMatch(host)) return 'not a plain host name';
  final labels = host.split('.');
  if (labels.length < 2) return 'single-label host';
  if (labels.any((l) => l.isEmpty || l.startsWith('-') || l.endsWith('-'))) {
    return 'malformed label';
  }
  if (RegExp(r'^\d+$').hasMatch(labels.last)) return 'IP address';
  // Top-level domains are alphabetic (or `xn--`): this refuses numeric
  // spellings a resolver may read as an address, such as `127.0.0.0x1`.
  if (!RegExp(r'^[a-z]').hasMatch(labels.last)) return 'numeric top label';
  if (_localSuffixes.any(host.endsWith)) return 'local name';
  return null;
}

/// What the host knows of a provider, copied once at registration: later
/// changes of the provider's getters do not move the hosts a request may
/// reach or the key consent is stored under.
class LyricsProviderRegistration {
  LyricsProviderRegistration._(
    this.provider,
    this.id,
    this.displayName,
    this.hosts,
  );

  /// Reads and validates [provider]. Throws [ArgumentError] for a malformed
  /// id, no host, or a host [lyricsHostProblem] rejects.
  factory LyricsProviderRegistration(LyricsProvider provider) {
    final id = provider.id;
    if (!_idPattern.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'malformed provider id');
    }
    // A set, so a repeated host is listed once.
    final hosts = {
      for (final host in provider.hosts) host.trim().toLowerCase(),
    }.toList()..sort();
    if (hosts.isEmpty) {
      throw ArgumentError.value(id, 'hosts', 'provider has no host');
    }
    for (final host in hosts) {
      final problem = lyricsHostProblem(host);
      if (problem != null) {
        throw ArgumentError.value(host, 'hosts', problem);
      }
    }
    return LyricsProviderRegistration._(
      provider,
      id,
      provider.displayName,
      List.unmodifiable(hosts),
    );
  }

  final LyricsProvider provider;
  final String id;
  final String displayName;

  /// Lower-case host names, unmodifiable.
  final List<String> hosts;
}

/// Registers [providers]; ids must be unique.
List<LyricsProviderRegistration> registerLyricsProviders(
  Iterable<LyricsProvider> providers,
) {
  final registrations = <LyricsProviderRegistration>[];
  final ids = <String>{};
  for (final provider in providers) {
    final registration = LyricsProviderRegistration(provider);
    if (!ids.add(registration.id)) {
      throw ArgumentError.value(registration.id, 'id', 'duplicate provider id');
    }
    registrations.add(registration);
  }
  return List.unmodifiable(registrations);
}

/// The lyrics providers that run, in the order they are tried: the enabled
/// entries of [lyricsSourcesProvider] (LRCLIB and the installed plugins) in
/// the user's order. A source whose registration fails (a plugin with a bad
/// host in a hand-edited database, say) is left out and logged. A disabled
/// source is not here; its stored lyrics are still named by
/// `lyricsSourceNamesProvider`.
final lyricsProvidersProvider = Provider<List<LyricsProviderRegistration>>((
  ref,
) {
  final runner = ref.watch(pluginScriptRunnerProvider);
  final registrations = <LyricsProviderRegistration>[];
  for (final entry in ref.watch(lyricsSourcesProvider)) {
    if (!entry.enabled) continue;
    final record = entry.record;
    try {
      if (record != null && runner == null) {
        throw StateError('the plugin runner is not available');
      }
      registrations.add(
        LyricsProviderRegistration(
          record == null
              ? LrclibProvider()
              : PluginLyricsProvider(record, runner!),
        ),
      );
    } on Object catch (e) {
      // Only the id and the reason: the plugin's name and hosts are its own
      // text, the reason names the field.
      final reason = e is ArgumentError ? ': ${e.message}' : '';
      _log.warning(
        'Lyrics source ${entry.id} skipped (${e.runtimeType}$reason)',
      );
    }
  }
  return List.unmodifiable(registrations);
});
