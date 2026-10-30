import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';
import 'package:material_ui/material_ui.dart';

import 'lyrics_sources_harness.dart';

const _limit = PluginConfigField(
  key: 'name',
  title: 'Display name',
  mode: PluginConfigMode.input,
  inputFormat: PluginInputFormat.text,
  defaultValue: 'Default name',
);

LyricsSourcePrefRow _pref(String id, int position) =>
    LyricsSourcePrefRow(providerId: id, enabled: true, position: position);

void main() {
  final a = testRecord(idA, name: 'Alpha');
  final b = testRecord(idB, name: 'Beta', installedAt: 2000);

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  /// Drags the first plugin below the second. [settle] false stops after the
  /// drop animation, short of the pause after which the page drops an order
  /// the database never confirmed.
  Future<void> dragFirstPluginBelowSecond(
    WidgetTester tester, {
    bool settle = true,
  }) async {
    final handle = find.byIcon(AppIcons.dragHandle).at(1);
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  group('source order', () {
    testWidgets('follows the database after it answers', (tester) async {
      final input = StreamController<LyricsSourcesInput>();
      addTearDown(input.close);
      input.add(LyricsSourcesInput([a, b], const []));
      final plugins = FakePlugins();
      await pumpSources(tester, plugins: plugins, input: input.stream);

      await dragFirstPluginBelowSecond(tester, settle: false);
      // Shown at once, before the database has answered.
      expect(top(tester, 'Beta'), lessThan(top(tester, 'Alpha')));

      // The database confirms, then another change puts Alpha first again.
      input.add(
        LyricsSourcesInput(
          [a, b],
          [_pref('lrclib', 0), _pref(idB, 1), _pref(idA, 2)],
        ),
      );
      await tester.pumpAndSettle();
      expect(top(tester, 'Beta'), lessThan(top(tester, 'Alpha')));

      input.add(
        LyricsSourcesInput(
          [a, b],
          [_pref('lrclib', 0), _pref(idA, 1), _pref(idB, 2)],
        ),
      );
      await tester.pumpAndSettle();
      expect(top(tester, 'Alpha'), lessThan(top(tester, 'Beta')));
    });

    testWidgets('goes back when saving the order throws', (tester) async {
      final plugins = FakePlugins()..reorderError = StateError('db');
      await pumpSources(tester, records: [a, b], plugins: plugins);

      await dragFirstPluginBelowSecond(tester);
      expect(plugins.reorders, hasLength(1));
      expect(top(tester, 'Alpha'), lessThan(top(tester, 'Beta')));
    });

    testWidgets('a plugin that vanishes mid-reorder leaves the saved order', (
      tester,
    ) async {
      final input = StreamController<LyricsSourcesInput>();
      addTearDown(input.close);
      input.add(LyricsSourcesInput([a, b], const []));
      await pumpSources(tester, plugins: FakePlugins(), input: input.stream);

      await dragFirstPluginBelowSecond(tester);
      input.add(LyricsSourcesInput([a], const []));
      await tester.pumpAndSettle();
      expect(find.text('Beta'), findsNothing);
      expect(find.text('Alpha'), findsOneWidget);
    });
  });

  group('plugin page', () {
    testWidgets('does not flash "no longer installed" while uninstalling', (
      tester,
    ) async {
      final input = StreamController<LyricsSourcesInput>();
      addTearDown(input.close);
      input.add(LyricsSourcesInput([a], const []));
      final plugins = FakePlugins()..uninstallGate = Completer<void>();
      await pumpSources(
        tester,
        plugins: plugins,
        input: input.stream,
        location: lyricsPluginRoute(idA),
      );

      await tester.tap(find.byTooltip(en.pluginUninstall));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.pluginUninstallConfirm));
      await tester.pumpAndSettle();
      // The record leaves the database before the call returns.
      input.add(const LyricsSourcesInput([], []));
      await tester.pumpAndSettle();
      expect(find.text(en.pluginGone), findsNothing);

      plugins.uninstallGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(en.lyricsSourcesStore), findsOneWidget);
      expect(find.text(en.pluginUninstalled('Alpha')), findsOneWidget);
    });

    testWidgets('a failing uninstall says so and keeps the page', (
      tester,
    ) async {
      final plugins = FakePlugins()..uninstallError = StateError('disk');
      await pumpSources(
        tester,
        records: [a],
        plugins: plugins,
        location: lyricsPluginRoute(idA),
      );
      await tester.tap(find.byTooltip(en.pluginUninstall));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.pluginUninstallConfirm));
      await tester.pumpAndSettle();

      expect(find.text(en.pluginUninstallFailed('Alpha')), findsOneWidget);
      expect(find.byTooltip(en.pluginUninstall), findsOneWidget);
    });

    testWidgets('does not pull the user back after they left the page', (
      tester,
    ) async {
      final plugins = FakePlugins()..uninstallGate = Completer<void>();
      final router = await pumpSources(
        tester,
        records: [a],
        plugins: plugins,
        location: lyricsPluginRoute(idA),
      );
      await tester.tap(find.byTooltip(en.pluginUninstall));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.pluginUninstallConfirm));
      await tester.pumpAndSettle();

      router.go('/settings');
      await tester.pumpAndSettle();
      plugins.uninstallGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('settings page'), findsOneWidget);
    });

    testWidgets('the enable switch survives a throwing controller', (
      tester,
    ) async {
      final plugins = _ThrowingEnable();
      await pumpSources(
        tester,
        records: [a],
        plugins: plugins,
        location: lyricsPluginRoute(idA),
      );
      await tester.tap(find.byType(Switch).first);
      await tester.pump();
      expect(plugins.calls, 1);
    });

    testWidgets('a stream error shows a retry', (tester) async {
      final input = StreamController<LyricsSourcesInput>();
      addTearDown(input.close);
      input.addError(StateError('db'));
      await pumpSources(
        tester,
        plugins: FakePlugins(),
        input: input.stream,
        location: lyricsPluginRoute(idA),
      );
      expect(find.text(en.pluginSourcesLoadFailed), findsOneWidget);
      expect(find.text(en.pluginRetry), findsOneWidget);
    });
  });

  group('settings form', () {
    final withField = testRecord(idA, name: 'Alpha', config: const [_limit]);

    Finder field() => find.widgetWithText(TextField, 'Display name');

    testWidgets('saves when the field loses focus, once', (tester) async {
      final plugins = FakePlugins();
      await pumpSources(
        tester,
        records: [withField],
        plugins: plugins,
        location: lyricsPluginRoute(idA),
      );
      await tester.enterText(field(), 'Mine');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(plugins.configWrites, [(idA, 'name', 'Mine')]);
    });

    testWidgets('saves an edit left in a focused field at teardown', (
      tester,
    ) async {
      final plugins = FakePlugins();
      final router = await pumpSources(
        tester,
        records: [withField],
        plugins: plugins,
        location: lyricsPluginRoute(idA),
      );
      await tester.enterText(field(), 'Pasted');
      router.go('/settings');
      await tester.pumpAndSettle();
      expect(plugins.configWrites, [(idA, 'name', 'Pasted')]);
    });

    testWidgets('text typed during a save is saved after it', (tester) async {
      final plugins = FakePlugins()..configGate = Completer<void>();
      await pumpSources(
        tester,
        records: [withField],
        plugins: plugins,
        location: lyricsPluginRoute(idA),
      );
      await tester.enterText(field(), 'a');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(plugins.configWrites, [(idA, 'name', 'a')]);

      await tester.enterText(field(), 'ab');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      // Held back until the first save ends.
      expect(plugins.configWrites, hasLength(1));

      final gate = plugins.configGate!;
      plugins.configGate = null;
      gate.complete();
      await tester.pumpAndSettle();
      expect(plugins.configWrites, [(idA, 'name', 'a'), (idA, 'name', 'ab')]);
      expect(tester.widget<TextField>(field()).controller!.text, 'ab');
    });

    testWidgets('keeps the typed text when the list emits again', (
      tester,
    ) async {
      final input = StreamController<LyricsSourcesInput>();
      addTearDown(input.close);
      input.add(LyricsSourcesInput([withField], const []));
      await pumpSources(
        tester,
        plugins: FakePlugins(),
        input: input.stream,
        location: lyricsPluginRoute(idA),
      );
      await tester.enterText(field(), 'draft');
      input.add(LyricsSourcesInput([withField], [_pref(idA, 1)]));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field()).controller!.text, 'draft');
    });

    testWidgets('a cleared field hints at the default', (tester) async {
      await pumpSources(
        tester,
        records: [withField],
        plugins: FakePlugins(),
        location: lyricsPluginRoute(idA),
      );
      await tester.enterText(field(), '');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Default name'), findsOneWidget);
    });

    testWidgets('a read error shows a retry that loads the form', (
      tester,
    ) async {
      final plugins = FakePlugins()..storedError = StateError('keyring');
      await pumpSources(
        tester,
        records: [withField],
        plugins: plugins,
        location: lyricsPluginRoute(idA),
      );
      expect(find.text(en.pluginConfigLoadFailed), findsOneWidget);

      plugins.storedError = null;
      await tester.tap(find.text(en.pluginRetry));
      await tester.pumpAndSettle();
      expect(field(), findsOneWidget);
    });
  });
}

class _ThrowingEnable extends FakePlugins {
  int calls = 0;

  @override
  Future<LyricsPluginWrite> setEnabled(String installId, bool on) async {
    calls++;
    throw StateError('db');
  }
}
