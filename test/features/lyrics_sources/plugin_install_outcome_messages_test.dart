import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_problem.dart';
import 'package:kanaru/features/lyrics_sources/plugin_install_failed_dialog.dart';
import 'package:kanaru/features/lyrics_sources/plugin_install_outcome_messages.dart';
import 'package:kanaru/l10n/l10n.dart';

import 'lyrics_sources_harness.dart';

void main() {
  final locales = {'en': en, 'vi': vi};

  group('pluginProblemMessage', () {
    for (final entry in locales.entries) {
      test('covers every problem kind in ${entry.key}', () {
        final texts = <String>{};
        for (final kind in PluginPackageProblemKind.values) {
          final text = pluginProblemMessage(
            entry.value,
            PluginPackageProblem(kind, detail: 'DETAIL', line: 7),
          );
          expect(text, isNotEmpty, reason: '$kind');
          texts.add(text);
        }
        // No two kinds share a text.
        expect(texts, hasLength(PluginPackageProblemKind.values.length));
      });
    }

    test('puts the detail and line into the texts that name them', () {
      String of(PluginPackageProblemKind k, {int? line}) =>
          pluginProblemMessage(
            en,
            PluginPackageProblem(k, detail: 'THE_DETAIL', line: line),
          );
      expect(of(PluginPackageProblemKind.unsafeEntry), contains('THE_DETAIL'));
      expect(
        of(PluginPackageProblemKind.invalidManifest),
        contains('THE_DETAIL'),
      );
      expect(of(PluginPackageProblemKind.badHost), contains('THE_DETAIL'));
      expect(
        of(PluginPackageProblemKind.missingScript),
        contains('THE_DETAIL'),
      );
      expect(of(PluginPackageProblemKind.scriptError), contains('THE_DETAIL'));
      expect(
        of(PluginPackageProblemKind.scriptError, line: 12),
        allOf(contains('THE_DETAIL'), contains('12')),
      );
    });

    test('a manifest problem without a field still reads well', () {
      expect(
        pluginProblemMessage(
          en,
          const PluginPackageProblem(PluginPackageProblemKind.invalidManifest),
        ),
        en.pluginProblemInvalidManifestPlain,
      );
    });
  });

  group('pluginInstallOutcomeReasons', () {
    final outcomes = <String, PluginInstallOutcome>{
      for (final kind in PluginPackageProblemKind.values)
        'rejected $kind': PluginInstallRejected(PluginPackageProblem(kind)),
      for (final reason in PluginUpdateRefusal.values)
        'refused $reason': PluginInstallRefused(reason),
      'secrets': const PluginInstallSecretsUnavailable(),
      'gone': const PluginInstallGone(),
    };

    for (final entry in locales.entries) {
      test('gives one text for every failing outcome in ${entry.key}', () {
        final seen = <String>{};
        for (final MapEntry(:key, :value) in outcomes.entries) {
          final reasons = pluginInstallOutcomeReasons(entry.value, value);
          expect(reasons, hasLength(1), reason: key);
          expect(reasons.single, isNotEmpty, reason: key);
          seen.add(reasons.single);
        }
        expect(seen, hasLength(outcomes.length));
      });
    }

    test('an installed plugin has no reasons', () {
      expect(
        pluginInstallOutcomeReasons(en, PluginInstalled(testRecord(idA))),
        isEmpty,
      );
    });

    test('a locked keyring says to unlock it or restart Kanaru', () {
      final text = pluginInstallOutcomeReasons(
        en,
        const PluginInstallSecretsUnavailable(),
      ).single;
      expect(text, allOf(contains('Unlock the keyring'), contains('restart')));
    });
  });

  group('dialog', () {
    Future<void> open(WidgetTester tester, PluginInstallOutcome outcome) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPluginInstallFailedDialog(
                context,
                sourceName: 'genius.zip',
                outcome: outcome,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('names the file and lists the reason', (tester) async {
      await open(
        tester,
        const PluginInstallRejected(
          PluginPackageProblem(
            PluginPackageProblemKind.badHost,
            detail: '192.168.1.5',
          ),
        ),
      );
      expect(find.text(en.pluginInstallFailedTitle), findsOneWidget);
      expect(
        find.text(en.pluginInstallFailedFile('genius.zip')),
        findsOneWidget,
      );
      expect(find.text(en.pluginInstallFailedReasons), findsOneWidget);
      expect(
        find.text('•  ${en.pluginProblemBadHost('192.168.1.5')}'),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text(en.pluginInstallFailedTitle), findsNothing);
    });

    testWidgets('does not name the file when the failure is not its fault', (
      tester,
    ) async {
      await open(tester, const PluginInstallGone());
      expect(find.text(en.pluginInstallFailedFile('genius.zip')), findsNothing);
      expect(find.text('•  ${en.pluginInstallGone}'), findsOneWidget);
    });

    testWidgets('shows nothing for an installed plugin', (tester) async {
      await open(tester, PluginInstalled(testRecord(idA)));
      expect(find.text(en.pluginInstallFailedTitle), findsNothing);
    });
  });
}
