import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_data_stats_provider.dart';
import 'package:kanaru/features/lyrics_sources/plugin_config_save.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';

import 'lyrics_sources_harness.dart';

const _secret = PluginConfigField(
  key: 'cookie',
  title: 'Cookie',
  mode: PluginConfigMode.input,
  inputFormat: PluginInputFormat.secret,
);
const _number = PluginConfigField(
  key: 'limit',
  title: 'Limit',
  mode: PluginConfigMode.input,
  inputFormat: PluginInputFormat.number,
  defaultValue: '10',
);
const _text = PluginConfigField(
  key: 'name',
  title: 'Display name',
  mode: PluginConfigMode.input,
  inputFormat: PluginInputFormat.text,
);
const _select = PluginConfigField(
  key: 'quality',
  title: 'Quality',
  mode: PluginConfigMode.select,
  options: [
    PluginConfigOption(value: 'synced', title: 'Synced first'),
    PluginConfigOption(value: 'plain', title: 'Plain only'),
  ],
  defaultValue: 'synced',
);
const _toggle = PluginConfigField(
  key: 'translate',
  title: 'With translation',
  mode: PluginConfigMode.toggle,
  defaultValue: false,
);

void main() {
  final plain = testRecord(
    idA,
    name: 'Alpha',
    hosts: const ['music.example.com', 'api.example.com'],
    kind: LyricsPluginSourceKind.repo,
    sourceName: 'Repo A',
    repoUrl: 'https://example.com/plugins.json',
    description: 'Synced lyrics',
  );
  final withConfig = testRecord(
    idA,
    name: 'Alpha',
    config: const [_secret, _number, _text, _select, _toggle],
  );

  Future<FakePlugins> open(
    WidgetTester tester,
    LyricsPluginRecord record, {
    FakePlugins? plugins,
    PluginDataStats stats = (storageBytes: 0, foundCount: 0, textBytes: 0),
  }) async {
    final fake = plugins ?? FakePlugins();
    await pumpSources(
      tester,
      records: [record],
      plugins: fake,
      stats: stats,
      location: lyricsPluginRoute(record.installId),
    );
    return fake;
  }

  testWidgets('shows the plugin, its hosts and no install id', (tester) async {
    await open(tester, plain);

    // The name is in the header card only; the app bar is generic.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text(en.pluginDetailsTitle), findsOneWidget);
    expect(find.text('someone (self-declared) · v3'), findsOneWidget);
    expect(find.text(en.pluginInfoHosts), findsOneWidget);
    expect(find.text('music.example.com'), findsOneWidget);
    expect(find.text('api.example.com'), findsOneWidget);
    expect(find.text('Repo: Repo A'), findsOneWidget);
    expect(find.text('https://example.com/plugins.json'), findsOneWidget);
    expect(find.text('Synced lyrics'), findsOneWidget);
    expect(find.textContaining(idA), findsNothing);
    expect(find.textContaining('plugin-'), findsNothing);
    // No settings form and no menu.
    expect(find.text(en.pluginConfigTitle), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('the trash button has a tooltip and a semantics label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await open(tester, plain);

    expect(find.byTooltip(en.pluginUninstall), findsOneWidget);
    expect(
      tester.getSemantics(find.byTooltip(en.pluginUninstall)),
      matchesSemantics(
        label: en.pluginUninstall,
        isButton: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
        tooltip: en.pluginUninstall,
      ),
    );
    handle.dispose();
  });

  testWidgets('the switch at the top calls setEnabled', (tester) async {
    final plugins = await open(tester, plain);
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(plugins.enabled, [(idA, false)]);
  });

  group('settings form', () {
    testWidgets('a secret is hidden, can be revealed, and saves on submit', (
      tester,
    ) async {
      final plugins = FakePlugins();
      await open(tester, withConfig, plugins: plugins);

      EditableText editable() => tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextField, 'Cookie'),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable().obscureText, isTrue);
      expect(find.text(en.pluginSecretNote), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Cookie'),
        's3cret',
      );
      await tester.tap(find.byTooltip(en.pluginSecretShow));
      await tester.pump();
      expect(editable().obscureText, isFalse);
      await tester.tap(find.byTooltip(en.pluginSecretHide));
      await tester.pump();
      expect(editable().obscureText, isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(plugins.configWrites, [(idA, 'cookie', 's3cret')]);
      // The value is not kept in the box; the note says it is saved.
      expect(find.text('s3cret'), findsNothing);
      expect(find.text(en.pluginSecretSaved), findsOneWidget);
    });

    testWidgets('a saved secret says so and can be removed', (tester) async {
      final plugins = FakePlugins()..secrets = {'cookie'};
      await open(tester, withConfig, plugins: plugins);

      expect(find.text(en.pluginSecretSaved), findsOneWidget);
      await tester.tap(find.byTooltip(en.pluginSecretClear));
      await tester.pumpAndSettle();
      expect(plugins.configWrites, [(idA, 'cookie', '')]);
      expect(find.text(en.pluginSecretNote), findsOneWidget);
    });

    testWidgets('without a system keyring the fallback warning replaces it', (
      tester,
    ) async {
      final plugins = FakePlugins()
        ..secrets = {'cookie'}
        ..fallback = true;
      await open(tester, withConfig, plugins: plugins);

      expect(find.text(en.pluginSecretFallbackNote), findsOneWidget);
      expect(find.text(en.pluginSecretSaved), findsNothing);
    });

    testWidgets('a failed keyring write says to unlock it or restart', (
      tester,
    ) async {
      final plugins = FakePlugins()
        ..configResult = PluginConfigWrite.secretStoreFailed;
      await open(tester, withConfig, plugins: plugins);

      await tester.enterText(find.widgetWithText(TextField, 'Cookie'), 'x');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text(en.pluginConfigSecretStoreFailed), findsOneWidget);
      expect(
        en.pluginConfigSecretStoreFailed,
        allOf(contains('Unlock the keyring'), contains('restart Kanaru')),
      );
      // Still not saved.
      expect(find.text(en.pluginSecretSaved), findsNothing);
    });

    testWidgets('every refusal has its own message', (tester) async {
      final texts = {
        for (final r in PluginConfigWrite.values)
          r: pluginConfigWriteMessage(en, r),
      };
      expect(texts[PluginConfigWrite.written], isNull);
      final shown = texts.values.whereType<String>().toList();
      expect(shown, hasLength(PluginConfigWrite.values.length - 1));
      expect(shown.toSet(), hasLength(shown.length));
    });

    testWidgets('a number is checked and a valid one is saved', (tester) async {
      final plugins = FakePlugins();
      await open(tester, withConfig, plugins: plugins);
      final field = find.widgetWithText(TextField, 'Limit');
      expect(
        tester.widget<TextField>(field).controller!.text,
        '10',
        reason: 'the manifest default',
      );

      await tester.enterText(field, '1e');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text(en.pluginConfigNumberInvalid), findsOneWidget);
      expect(plugins.configWrites, isEmpty);

      await tester.enterText(field, '25.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(plugins.configWrites, [(idA, 'limit', '25.5')]);
      expect(find.text(en.pluginConfigNumberInvalid), findsNothing);
    });

    testWidgets('a text field shows its saved value and saves on submit', (
      tester,
    ) async {
      final plugins = FakePlugins()..stored = {'name': 'Mine'};
      await open(tester, withConfig, plugins: plugins);
      final field = find.widgetWithText(TextField, 'Display name');
      expect(tester.widget<TextField>(field).controller!.text, 'Mine');
      await tester.enterText(field, 'Yours');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(plugins.configWrites, [(idA, 'name', 'Yours')]);
    });

    testWidgets('a select saves its choice, a toggle saves its state', (
      tester,
    ) async {
      final plugins = FakePlugins();
      await open(tester, withConfig, plugins: plugins);

      expect(find.text('Synced first'), findsOneWidget);
      await tester.tap(find.text('Synced first'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plain only').last);
      await tester.pumpAndSettle();
      expect(plugins.configWrites, [(idA, 'quality', 'plain')]);

      await tester.tap(find.widgetWithText(SwitchListTile, 'With translation'));
      await tester.pumpAndSettle();
      expect(plugins.configWrites.last, (idA, 'translate', true));
    });

    testWidgets('a refused toggle flips back and says why', (tester) async {
      final plugins = FakePlugins()..configResult = PluginConfigWrite.tooLarge;
      await open(tester, withConfig, plugins: plugins);

      await tester.tap(find.widgetWithText(SwitchListTile, 'With translation'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'With translation'),
            )
            .value,
        isFalse,
      );
      expect(find.text(en.pluginConfigTooLarge), findsOneWidget);
    });
  });

  group('data', () {
    const stats = (storageBytes: 3200, foundCount: 57, textBytes: 215040);

    testWidgets('shows both sizes and clears each one after a confirm', (
      tester,
    ) async {
      final plugins = FakePlugins();
      await open(tester, plain, plugins: plugins, stats: stats);

      expect(find.text('3 KB / 64 KB'), findsOneWidget);
      expect(find.text('57 songs · 210 KB'), findsOneWidget);

      final clear = find.text(en.pluginDataClear);
      await tester.tap(clear.first);
      await tester.pumpAndSettle();
      expect(find.text(en.pluginStorageClearTitle), findsOneWidget);
      await tester.tap(find.text(en.pluginDataClear).last);
      await tester.pumpAndSettle();
      expect(plugins.storageClears, [idA]);
      expect(find.text(en.pluginStorageCleared), findsOneWidget);

      await tester.tap(find.text(en.pluginDataClear).last);
      await tester.pumpAndSettle();
      expect(find.text(en.pluginSavedLyricsClearTitle), findsOneWidget);
      await tester.tap(find.text(en.pluginDataClear).last);
      await tester.pumpAndSettle();
      expect(plugins.lyricsClears, [idA]);
    });

    testWidgets('cancelling the confirm clears nothing', (tester) async {
      final plugins = FakePlugins();
      await open(tester, plain, plugins: plugins, stats: stats);

      await tester.tap(find.text(en.pluginDataClear).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(plugins.storageClears, isEmpty);
      expect(plugins.lyricsClears, isEmpty);
    });

    testWidgets('has no Delete button when there is nothing to delete', (
      tester,
    ) async {
      await open(tester, plain);
      final buttons = tester.widgetList<TextButton>(
        find.widgetWithText(TextButton, en.pluginDataClear),
      );
      expect(buttons.every((b) => b.onPressed == null), isTrue);
      expect(find.text(en.pluginSavedLyricsNone), findsOneWidget);
    });
  });

  group('uninstall', () {
    const stats = (storageBytes: 3200, foundCount: 57, textBytes: 215040);

    testWidgets('the dialog lists what goes and what stays, with counts', (
      tester,
    ) async {
      final plugins = FakePlugins();
      await open(tester, withConfig, plugins: plugins, stats: stats);

      await tester.tap(find.byTooltip(en.pluginUninstall));
      await tester.pumpAndSettle();

      expect(find.text(en.pluginUninstallTitle('Alpha')), findsOneWidget);
      expect(find.text(en.pluginUninstallRemoves), findsOneWidget);
      expect(find.text(en.pluginUninstallKeeps), findsOneWidget);
      expect(
        find.textContaining(en.pluginUninstallStorage('3 KB')),
        findsOneWidget,
      );
      expect(
        find.textContaining(en.pluginUninstallKeepLyrics(57)),
        findsOneWidget,
      );
      expect(
        find.textContaining(en.pluginUninstallSettingsSecret),
        findsOneWidget,
      );
      expect(plugins.uninstalls, isEmpty);
    });

    testWidgets('cancel keeps the plugin', (tester) async {
      final plugins = FakePlugins();
      await open(tester, plain, plugins: plugins, stats: stats);
      await tester.tap(find.byTooltip(en.pluginUninstall));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(plugins.uninstalls, isEmpty);
      expect(find.byTooltip(en.pluginUninstall), findsOneWidget);
    });

    testWidgets('confirming uninstalls, returns to the list and says so', (
      tester,
    ) async {
      final plugins = FakePlugins();
      await open(tester, plain, plugins: plugins, stats: stats);
      await tester.tap(find.byTooltip(en.pluginUninstall));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.pluginUninstallConfirm));
      await tester.pumpAndSettle();

      expect(plugins.uninstalls, [idA]);
      // Back on the sources list (its Plugin store button), with the note.
      expect(find.text(en.lyricsSourcesStore), findsOneWidget);
      expect(find.text(en.pluginUninstalled('Alpha')), findsOneWidget);
    });
  });

  testWidgets('a plugin that is not installed shows a gone state', (
    tester,
  ) async {
    await pumpSources(
      tester,
      plugins: FakePlugins(),
      location: lyricsPluginRoute('plugin-zzzzzzzzzzzz'),
    );
    expect(find.text(en.pluginGone), findsOneWidget);
    await tester.tap(find.text(en.lyricsSourcesTitle).last);
    await tester.pumpAndSettle();
    expect(find.text(en.lyricsSourcesStore), findsOneWidget);
  });
}
