import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/settings/settings_category_tile.dart';

/// On the Settings root, taps the tile titled [tileTitle] and waits for the
/// page to slide in. [settle] replaces `pumpAndSettle` for tests that need
/// their own wait (real I/O).
Future<void> openSettingsPage(
  WidgetTester tester,
  String tileTitle, {
  Future<void> Function()? settle,
}) async {
  await tester.tap(find.widgetWithText(SettingsCategoryTile, tileTitle));
  await (settle ?? tester.pumpAndSettle)();
}
