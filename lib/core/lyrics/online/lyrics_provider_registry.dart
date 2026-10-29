import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lrclib_provider.dart';
import 'lyrics_provider.dart';

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
    // A set, so a repeated host cannot change the consent key.
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

  /// What the user agrees to: this provider at these hosts. A provider whose
  /// hosts change gets a new key, so the user is asked again.
  String get consentKey => '$id@${([...hosts]..sort()).join(',')}';

  /// Consent to look lyrics up without being asked each time.
  String get autoConsentKey => '$consentKey:auto';
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

/// Every lyrics provider the app knows, in the order they are tried.
final lyricsProvidersProvider = Provider<List<LyricsProviderRegistration>>(
  (ref) => registerLyricsProviders([LrclibProvider()]),
);
