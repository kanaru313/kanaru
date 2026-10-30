import 'dart:async';
import 'dart:io';

import 'lyrics_http_pinned_connect.dart' show LyricsSocketDialer;

/// One connection attempt over the checked addresses, IPv4 first; [cancel]
/// stops it. Built by `lyricsPinnedConnectionFactory`.
class LyricsPinnedAttempt {
  LyricsPinnedAttempt({
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
            // A socket that still completes later must not leak.
            unawaited(task.socket.then((s) => s.destroy(), onError: (_) {}));
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
