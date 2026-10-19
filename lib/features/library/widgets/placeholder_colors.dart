import 'package:material_ui/material_ui.dart';

import 'stable_hash.dart';

/// Background and foreground of a placeholder picture, picked from [seed]
/// among the container colors, the same on every launch.
(Color, Color) placeholderColors(ColorScheme scheme, String seed) {
  final pairs = [
    (scheme.primaryContainer, scheme.onPrimaryContainer),
    (scheme.secondaryContainer, scheme.onSecondaryContainer),
    (scheme.tertiaryContainer, scheme.onTertiaryContainer),
  ];
  return pairs[fnv1a(seed) % pairs.length];
}
