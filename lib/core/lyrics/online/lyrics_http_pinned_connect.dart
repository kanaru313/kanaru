import 'dart:async';
import 'dart:io';

import '../../lyrics_translation/translation_failure.dart';
import 'lyrics_http_address_class.dart';

/// Resolves a host name to its addresses. Tests replace it.
typedef LyricsHostResolver = Future<List<InternetAddress>> Function(
  String host,
);

/// Opens a connection to one already checked [address]. Tests replace it.
typedef LyricsSocketDialer = Future<ConnectionTask<Socket>> Function(
  InternetAddress address,
  int port,
);

/// Looks at everything [url] resolved to and throws to refuse the connection.
typedef LyricsPinnedCheck = void Function(
  Uri url,
  List<InternetAddress> addresses,
);

/// The type of `HttpClient.connectionFactory`.
typedef LyricsConnectionFactory = Future<ConnectionTask<Socket>> Function(
  Uri url,
  String? proxyHost,
  int? proxyPort,
);

/// The system resolver.
Future<List<InternetAddress>> systemLyricsHostResolver(String host) =>
    InternetAddress.lookup(host);

/// Refusal of a destination whose addresses are not allowed. It is a
/// [TranslationException] of kind `blocked` because the request helper
/// rethrows those unchanged; the lyrics send loop turns it into
/// `LyricsFetchKind.blockedHost`. Carries only the class found, never the
/// host or the addresses.
class LyricsBlockedAddressException extends TranslationException {
  const LyricsBlockedAddressException(this.found)
    : super(TranslationFailureKind.blocked);

  final LyricsAddressClass found;
}

/// A connection factory for `HttpClient` that closes the DNS rebinding gap:
/// the name is resolved exactly once, `check` sees every address of that one
/// answer, and the connection goes to those addresses and to nothing a later
/// lookup could return.
///
/// * An IP literal in the URL is checked without a lookup.
/// * For `https` the TLS handshake runs on the connected socket with the
///   original host name (so SNI and certificate checks use the name, not the
///   address). No bad-certificate callback is ever set, so an untrusted
///   certificate fails the connection; [context] only adds trust anchors.
/// * Addresses are tried IPv4 first, then IPv6, one after the other. The whole
///   connect (dials and TLS handshake) is bounded by [connectTimeout]; each
///   dial gets an equal share of what is left, so one blackholed address does
///   not use up the budget of the next. A cancelled connection stops dialing
///   and destroys its sockets.
/// * When `HttpClient` uses a proxy (its own `findProxy`, normally from the
///   environment) the proxy resolves the name, so the pinned check cannot see
///   that answer. The factory still looks the name up locally first (bounded
///   by [proxyLookupTimeout]) and refuses when that answer fails `check`; when
///   the local lookup fails (a network that only reaches the proxy) it
///   connects to the proxy as configured. This stops a name that statically
///   points at the user's own machine; it is not proof against a name that
///   answers differently to the proxy.
LyricsConnectionFactory lyricsPinnedConnectionFactory({
  required LyricsPinnedCheck check,
  LyricsHostResolver resolver = systemLyricsHostResolver,
  LyricsSocketDialer dialer = _systemDialer,
  SecurityContext? context,
  Duration resolveTimeout = const Duration(seconds: 10),
  Duration connectTimeout = const Duration(seconds: 10),
  Duration proxyLookupTimeout = const Duration(seconds: 3),
}) {
  return (url, proxyHost, proxyPort) async {
    if (proxyHost != null && proxyPort != null) {
      await _checkBeforeProxy(url, check, resolver, proxyLookupTimeout);
      return Socket.startConnect(proxyHost, proxyPort);
    }
    final addresses = await _resolveOnce(url.host, resolver, resolveTimeout);
    check(url, addresses);
    final attempt = _PinnedAttempt(
      host: url.host,
      port: url.port,
      secure: url.scheme == 'https',
      addresses: addresses,
      dialer: dialer,
      context: context,
      budget: connectTimeout,
    );
    return ConnectionTask.fromSocket(attempt.connect(), attempt.cancel);
  };
}

/// Runs [check] on what [url] resolves to locally before the connection goes
/// to a proxy. A lookup that fails (no DNS without the proxy) is not a
/// refusal: the proxy is used as configured.
Future<void> _checkBeforeProxy(
  Uri url,
  LyricsPinnedCheck check,
  LyricsHostResolver resolver,
  Duration timeout,
) async {
  final List<InternetAddress> addresses;
  try {
    addresses = await _resolveOnce(url.host, resolver, timeout);
  } on SocketException {
    return;
  }
  check(url, addresses);
}

/// A factory that accepts public destinations only: the guard for plugin and
/// LRCLIB traffic, whose hosts are public names. A name that resolves to any
/// non-public address (or to a mix) fails with [LyricsBlockedAddressException]
/// before a socket is opened.
LyricsConnectionFactory lyricsPublicOnlyConnectionFactory({
  LyricsHostResolver resolver = systemLyricsHostResolver,
  LyricsSocketDialer dialer = _systemDialer,
  SecurityContext? context,
  Duration resolveTimeout = const Duration(seconds: 10),
  Duration connectTimeout = const Duration(seconds: 10),
  Duration proxyLookupTimeout = const Duration(seconds: 3),
}) => lyricsPinnedConnectionFactory(
  check: (url, addresses) {
    final found = classifyLyricsAddresses(addresses);
    if (found != LyricsAddressClass.public) {
      throw LyricsBlockedAddressException(found);
    }
  },
  resolver: resolver,
  dialer: dialer,
  context: context,
  resolveTimeout: resolveTimeout,
  connectTimeout: connectTimeout,
  proxyLookupTimeout: proxyLookupTimeout,
);

Future<ConnectionTask<Socket>> _systemDialer(
  InternetAddress address,
  int port,
) => Socket.startConnect(address, port);

Future<List<InternetAddress>> _resolveOnce(
  String host,
  LyricsHostResolver resolver,
  Duration timeout,
) async {
  final literal = InternetAddress.tryParse(host);
  if (literal != null) return [literal];
  final List<InternetAddress> found;
  try {
    found = await resolver(host).timeout(timeout);
  } on TimeoutException {
    throw const SocketException('Host lookup timed out');
  }
  if (found.isEmpty) throw const SocketException('Host lookup found nothing');
  return found;
}

/// One connection attempt over the checked addresses; [cancel] stops it.
class _PinnedAttempt {
  _PinnedAttempt({
    required this.host,
    required this.port,
    required this.secure,
    required List<InternetAddress> addresses,
    required this.dialer,
    required this.context,
    required this.budget,
  }) : addresses = [
         ...addresses.where((a) => a.type == InternetAddressType.IPv4),
         ...addresses.where((a) => a.type != InternetAddressType.IPv4),
       ];

  final String host;
  final int port;
  final bool secure;
  final List<InternetAddress> addresses;
  final LyricsSocketDialer dialer;
  final SecurityContext? context;
  final Duration budget;

  bool _cancelled = false;
  ConnectionTask<Socket>? _dialing;
  Socket? _open;

  Future<Socket> connect() async {
    final clock = Stopwatch()..start();
    Object? last;
    for (var i = 0; i < addresses.length; i++) {
      if (_cancelled) break;
      final remaining = budget - clock.elapsed;
      if (remaining <= Duration.zero) break;
      // An equal share of what is left for this and the addresses after it.
      final slice = remaining ~/ (addresses.length - i);
      try {
        final task = await dialer(addresses[i], port);
        _dialing = task;
        if (_cancelled) {
          // Cancelling fails the task's socket future; observe it so that
          // failure (or a socket that opened first) does not go unhandled.
          unawaited(task.socket.then((s) => s.destroy(), onError: (_) {}));
          task.cancel();
          break;
        }
        final plain = await task.socket.timeout(
          slice,
          onTimeout: () {
            task.cancel();
            throw const SocketException('Connection timed out');
          },
        );
        _open = plain;
        if (_cancelled) {
          plain.destroy();
          break;
        }
        if (!secure) return plain;
        final tls =
            await SecureSocket.secure(
              plain,
              host: host,
              context: context,
            ).timeout(
              budget - clock.elapsed,
              onTimeout: () {
                plain.destroy();
                throw const SocketException('TLS handshake timed out');
              },
            );
        _open = tls;
        if (_cancelled) {
          tls.destroy();
          break;
        }
        return tls;
      } on SocketException catch (e) {
        last = e;
      } on Object {
        // Destroying the socket of a cancelled attempt fails its handshake;
        // that is the cancellation, not an error to report.
        if (_cancelled) break;
        rethrow;
      }
    }
    throw last ?? const SocketException('Connection cancelled');
  }

  void cancel() {
    _cancelled = true;
    _dialing?.cancel();
    _open?.destroy();
  }
}
