import '../../hls/hls_refusal.dart';
import '../stream_resolver.dart';

/// A resolve ended because the HLS playlist must not be played or could not
/// be taken in. Only [kind] is logged (`hls <kind>`), never a URL.
class HlsResolveFailure extends ResolveFailure {
  HlsResolveFailure(this.kind) : super('hls ${kind.name}');

  final HlsRefusalKind kind;
}
