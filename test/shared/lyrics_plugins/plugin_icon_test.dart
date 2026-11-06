import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/shared/lyrics_plugins/plugin_icon.dart';
import 'package:material_ui/material_ui.dart';

LyricsPluginRecord _record({int? removedAt}) => LyricsPluginRecord(
  installId: 'plugin-aaaaaaaaaaaa',
  kind: null,
  name: 'Zing',
  version: 1,
  apiVersion: 1,
  hosts: const [],
  config: const [],
  packageDir: 'plugin-aaaaaaaaaaaa/v1-1',
  sourceKind: LyricsPluginSourceKind.file,
  sourceName: 'z.zip',
  installedAt: 1,
  updatedAt: 1,
  removedAt: removedAt,
);

Future<void> _pump(
  WidgetTester tester,
  LyricsPluginRecord? record, {
  String? letterOf,
}) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      home: PluginIcon(record: record, letterOf: letterOf),
    ),
  ),
);

void main() {
  testWidgets('null record with letterOf draws the upper-cased first letter', (
    tester,
  ) async {
    await _pump(tester, null, letterOf: 'lrclib');
    expect(find.text('L'), findsOneWidget);
    expect(find.byIcon(pluginDefaultIcon), findsNothing);
  });

  testWidgets('removed record with letterOf draws the letter', (tester) async {
    await _pump(tester, _record(removedAt: 5), letterOf: 'zing');
    expect(find.text('Z'), findsOneWidget);
  });

  testWidgets('without letterOf the fallback icon is drawn', (tester) async {
    await _pump(tester, null);
    expect(find.byIcon(pluginDefaultIcon), findsOneWidget);
  });

  testWidgets('live record with letterOf keeps the icon path', (tester) async {
    await _pump(tester, _record(), letterOf: 'zing');
    expect(find.text('Z'), findsNothing);
    expect(find.byIcon(pluginDefaultIcon), findsOneWidget);
  });

  testWidgets('letterOf draws the whole first grapheme', (tester) async {
    await _pump(tester, null, letterOf: 'éclair');
    expect(find.text('É'), findsOneWidget);
    await _pump(tester, null, letterOf: '👨‍👩‍👧 family');
    expect(find.text('👨‍👩‍👧'), findsOneWidget);
  });
}
