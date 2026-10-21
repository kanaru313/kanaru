import 'package:logging/logging.dart';

import '../../src/rust/frb_generated.dart';

final _log = Logger('rust_library');

Future<void>? _ready;

/// Initialises the native bridge once for the whole app. Every reader of the
/// native library calls this before its first call, so two of them starting
/// together share one init (the bridge throws if initialised twice). A failed
/// attempt is forgotten so a later call can retry instead of replaying the
/// same error forever. Skips the init when something else already did it.
Future<void> ensureRustLibraryLoaded() {
  if (RustLib.instance.initialized) return Future<void>.value();
  return _ready ??= RustLib.init().catchError((Object error, StackTrace st) {
    _log.severe('Cannot load the native library', error, st);
    _ready = null;
    Error.throwWithStackTrace(error, st);
  });
}
