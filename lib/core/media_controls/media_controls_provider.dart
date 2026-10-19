import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_controls.dart';

/// The platform's media controls. Defaults to [NoopMediaControls]; the app
/// overrides it at startup with the real implementation.
final mediaControlsProvider = Provider<MediaControls>(
  (ref) => NoopMediaControls(),
);

/// What a "raise the window" request from the desktop does. The app
/// overrides it; by default there is no window to raise.
final mediaControlsRaiseProvider = Provider<Future<void> Function()>(
  (ref) => () async {},
);
