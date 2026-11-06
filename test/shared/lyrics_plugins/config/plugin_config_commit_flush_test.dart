import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/lyrics_plugins/config/plugin_config_flush_group.dart';
import 'package:kanaru/shared/lyrics_plugins/config/plugin_config_text_field.dart';
import 'package:kanaru/shared/lyrics_plugins/config/plugin_config_toggle_field.dart';
import 'package:material_ui/material_ui.dart';

import '../../../features/lyrics_sources/lyrics_sources_harness.dart';

class _RecordingJobs extends TranslationJobs {
  final cleared = <TranslationServiceId>[];

  @override
  void clearFailures(TranslationServiceId service) => cleared.add(service);
}

const _name = PluginConfigField(
  key: 'k',
  title: 'Name',
  mode: PluginConfigMode.input,
  minLength: 3,
);

void main() {
  late FakePlugins plugins;
  late _RecordingJobs jobs;
  late PluginConfigFlushGroup group;

  setUp(() {
    plugins = FakePlugins();
    jobs = _RecordingJobs();
    group = PluginConfigFlushGroup();
    addTearDown(group.dispose);
  });

  Future<void> pump(
    WidgetTester tester, {
    bool forgetsFailures = true,
    bool withGroup = true,
    Widget? child,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        lyricsPluginsControllerProvider.overrideWithValue(plugins),
        translationJobsProvider.overrideWith(() => jobs),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body:
              child ??
              PluginConfigTextField(
                installId: idA,
                field: _name,
                initialText: '',
                forgetsFailures: forgetsFailures,
                flushGroup: withGroup ? group : null,
              ),
        ),
      ),
    ),
  );

  testWidgets('a valid edit is saved and flush says so', (tester) async {
    await pump(tester);
    expect(group.anyDirty.value, isFalse);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    expect(group.anyDirty.value, isTrue);

    final ok = await tester.runAsync(group.flushAll);
    await tester.pump();

    expect(ok, isTrue);
    expect(plugins.configWrites, [(idA, 'k', 'hello')]);
    expect(group.anyDirty.value, isFalse);
  });

  testWidgets('an invalid edit is not saved and flush says so', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump();

    final ok = await tester.runAsync(group.flushAll);
    await tester.pump();

    expect(ok, isFalse);
    expect(plugins.configWrites, isEmpty);
    expect(group.anyDirty.value, isTrue);
  });

  testWidgets('a refused save makes flush false', (tester) async {
    plugins.configResult = PluginConfigWrite.invalidValue;
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();

    expect(await tester.runAsync(group.flushAll), isFalse);
    await tester.pump();
    expect(find.text(en.pluginConfigInvalidValue), findsOneWidget);
  });

  testWidgets('flush waits for the save under way and the one queued', (
    tester,
  ) async {
    plugins.configGate = Completer<void>();
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();

    bool? first;
    bool? second;
    unawaited(group.flushAll().then((ok) => first = ok));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'abcd');
    unawaited(group.flushAll().then((ok) => second = ok));
    await tester.pump();
    expect(plugins.configWrites.map((w) => w.$3), ['abc']);
    expect([first, second], [null, null], reason: 'the first save is held');

    plugins.configGate!.complete();
    await tester.pumpAndSettle();

    expect([first, second], [true, true]);
    expect(plugins.configWrites.map((w) => w.$3), ['abc', 'abcd']);
    expect(group.anyDirty.value, isFalse);
  });

  testWidgets('forgetting failures is on by default and can be turned off', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.runAsync(group.flushAll);
    expect(jobs.cleared.map((s) => s.value), [idA]);

    jobs.cleared.clear();
    plugins.configWrites.clear();
    await pump(tester, forgetsFailures: false);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'other');
    await tester.runAsync(group.flushAll);
    expect(plugins.configWrites, [(idA, 'k', 'other')]);
    expect(jobs.cleared, isEmpty);
  });

  testWidgets('teardown saving does not forget failures when told not to', (
    tester,
  ) async {
    await pump(tester, forgetsFailures: false);
    await tester.enterText(find.byType(TextField), 'torn down');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(plugins.configWrites, [(idA, 'k', 'torn down')]);
    expect(jobs.cleared, isEmpty);
  });

  testWidgets('a field leaving the group is no longer dirty', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'abcd');
    expect(group.anyDirty.value, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(group.anyDirty.value, isFalse);
  });

  testWidgets('a toggle joins a group and flushes', (tester) async {
    const toggle = PluginConfigField(
      key: 'flag',
      title: 'Flag',
      mode: PluginConfigMode.toggle,
    );
    await pump(
      tester,
      child: PluginConfigToggleField(
        installId: idA,
        field: toggle,
        initialValue: false,
        flushGroup: group,
        forgetsFailures: false,
        padding: EdgeInsets.zero,
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(await tester.runAsync(group.flushAll), isTrue);
    expect(plugins.configWrites, [(idA, 'flag', true)]);
    expect(jobs.cleared, isEmpty);
  });
  testWidgets('flush ends when the editor goes with a save queued', (
    tester,
  ) async {
    plugins.configGate = Completer<void>();
    Widget app(bool show) => ProviderScope(
      overrides: [
        lyricsPluginsControllerProvider.overrideWithValue(plugins),
        translationJobsProvider.overrideWith(() => jobs),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: show
              ? PluginConfigTextField(
                  installId: idA,
                  field: const PluginConfigField(
                    key: 'k',
                    title: 'Name',
                    mode: PluginConfigMode.input,
                  ),
                  initialText: '',
                  flushGroup: group,
                )
              : const SizedBox(),
        ),
      ),
    );
    await tester.pumpWidget(app(true));
    await tester.enterText(find.byType(TextField), 'one');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'two');
    await tester.pump();
    bool? result;
    unawaited(group.flushAll().then((ok) => result = ok));
    await tester.pump();
    final gate = plugins.configGate!;
    plugins.configGate = null;
    await tester.pumpWidget(app(false));
    gate.complete();
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('a group disposed by its owner while a field is dirty', (
    tester,
  ) async {
    final owned = PluginConfigFlushGroup();
    await pump(
      tester,
      child: PluginConfigTextField(
        installId: idA,
        field: _name,
        initialText: '',
        flushGroup: owned,
      ),
    );
    await tester.enterText(find.byType(TextField), 'dirty');
    await tester.pump();
    expect(owned.anyDirty.value, isTrue);
    // The owner disposes the group before the field is torn down.
    owned.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('flush is true after a save that came back on the live values', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lyricsPluginsControllerProvider.overrideWithValue(plugins),
          translationJobsProvider.overrideWith(() => jobs),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StreamBuilder<Map<String, Object?>>(
              stream: plugins.storedStream(idA),
              builder: (context, snapshot) => PluginConfigTextField(
                installId: idA,
                field: const PluginConfigField(
                  key: 'k',
                  title: 'Name',
                  mode: PluginConfigMode.input,
                ),
                initialText: '${snapshot.data?['k'] ?? ''}',
                flushGroup: group,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'hello');
    bool? ok;
    unawaited(group.flushAll().then((v) => ok = v));
    await tester.pumpAndSettle();

    expect(ok, isTrue);
    expect(plugins.configWrites.map((w) => w.$3), ['hello']);
    expect(find.text('hello'), findsOneWidget);
  });
}
