import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'app/shell/window/desktop_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final customTitleBar = await setUpDesktopWindow();

  runApp(
    ProviderScope(
      overrides: [customTitleBarProvider.overrideWithValue(customTitleBar)],
      child: const KanaruApp(),
    ),
  );
}
