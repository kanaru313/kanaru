import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tells listeners that a source plugin's streams were stopped: it was
/// uninstalled or its notice was withdrawn. The stream proxy adds the install
/// id once it has ended that plugin's responses and refuses its items; the
/// player stops when its current track belongs to it.
class SourcePluginDrops {
  final _controller = StreamController<String>.broadcast();

  /// Install ids of dropped plugins, as they happen.
  Stream<String> get stream => _controller.stream;

  /// Called by the stream proxy after it stopped [installId]'s streams.
  void add(String installId) {
    if (!_controller.isClosed) _controller.add(installId);
  }

  Future<void> close() => _controller.close();
}

/// The drop signal. Has no dependencies, so listening to it starts neither
/// the stream proxy nor a read of the plugin records.
final sourcePluginDropsProvider = Provider<SourcePluginDrops>((ref) {
  final drops = SourcePluginDrops();
  ref.onDispose(drops.close);
  return drops;
});
