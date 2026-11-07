import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../hls/hls_refusal.dart';
import '../remote_source_ref.dart';
import 'hls/hls_resolve_failure.dart';
import 'stream_proxy_server.dart';

final _log = Logger('source_proxy');

/// Why a stream was refused in a way the user is told about, other than the
/// general "couldn't play".
enum StreamRefusal {
  /// A live stream (an HLS playlist that never ends).
  live,

  /// A protected stream (DRM, or a cipher the app does not play).
  protected,
}

/// The refusal [failure], the error of an item's last resolve, stands for;
/// null for any other failure (or none).
StreamRefusal? streamRefusalOf(Object? failure) => switch (failure) {
  HlsResolveFailure(kind: HlsRefusalKind.live) => StreamRefusal.live,
  HlsResolveFailure(kind: HlsRefusalKind.protected) => StreamRefusal.protected,
  _ => null,
};

/// Asks why the last resolve of a remote item failed. Reads the stream proxy
/// only when called (so it never starts one just for being watched) and
/// answers null when it cannot (logged as the error type); never throws.
final remoteStreamRefusalProvider =
    Provider<StreamRefusal? Function(RemoteSourceRef)>(
      (ref) => (item) {
        try {
          return streamRefusalOf(
            ref.read(sourceStreamProxyProvider).lastFailureOf(item),
          );
        } on Object catch (error) {
          // The type only: the message may name a URL.
          _log.warning(
            'Could not read why a stream was refused: ${error.runtimeType}',
          );
          return null;
        }
      },
    );
