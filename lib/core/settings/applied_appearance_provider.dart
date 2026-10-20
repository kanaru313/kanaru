import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

/// The settings that rebuild the whole app when they change.
typedef AppAppearance = ({ThemePreference theme, String? languageCode});

/// How long the choice must stay unchanged before the app switches to it.
const appearanceApplyDelay = Duration(milliseconds: 600);

/// The theme and language the app is showing. It follows [settingsProvider]
/// after [appearanceApplyDelay] without a change, so clicking through the
/// options shows only the last one instead of flashing the whole screen. The
/// value at startup applies at once. The settings themselves (and the file)
/// still change right away.
class AppliedAppearanceNotifier extends Notifier<AppAppearance> {
  Timer? _timer;

  @override
  AppAppearance build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(settingsProvider.select(_appearanceOf), (_, next) {
      _timer?.cancel();
      _timer = Timer(appearanceApplyDelay, () => state = next);
    });
    return _appearanceOf(ref.read(settingsProvider));
  }

  static AppAppearance _appearanceOf(AppSettings s) =>
      (theme: s.theme, languageCode: s.languageCode);
}

final appliedAppearanceProvider =
    NotifierProvider<AppliedAppearanceNotifier, AppAppearance>(
      AppliedAppearanceNotifier.new,
    );
