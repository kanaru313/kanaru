import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_problem.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_repo.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_operation_results.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_install_outcome.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/lyrics_plugins/plugin_failure_text.dart';
import 'package:kanaru/shared/lyrics_plugins/plugin_problem_text.dart';

import '../../features/lyrics_plugin_store/store_test_harness.dart'
    show recordOf;

AppLocalizations _of(String code) => lookupAppLocalizations(Locale(code));

void main() {
  final locales = {'en': _of('en'), 'vi': _of('vi')};

  for (final MapEntry(key: code, value: l10n) in locales.entries) {
    group('texts in $code', () {
      test('every package problem kind has its own text', () {
        final texts = <String>{};
        for (final kind in PluginPackageProblemKind.values) {
          final text = pluginProblemText(
            l10n,
            PluginPackageProblem(kind, detail: 'DETAIL', line: 7),
          );
          expect(text, isNotEmpty, reason: kind.name);
          texts.add(text);
        }
        expect(texts, hasLength(PluginPackageProblemKind.values.length));
      });

      test('every install failure has a text', () {
        for (final failure in RepoPluginFailure.values) {
          expect(
            repoPluginFailureText(l10n, RepoPluginFailed(failure)),
            isNotEmpty,
            reason: failure.name,
          );
        }
      });

      test(
        'every download error has its own text, a missing one is network',
        () {
          final texts = <String>{
            for (final kind in RepoFetchErrorKind.values)
              pluginDownloadReasonText(l10n, RepoLoadError(kind)),
          };
          expect(texts, hasLength(RepoFetchErrorKind.values.length));
          expect(
            pluginDownloadReasonText(l10n, null),
            pluginDownloadReasonText(
              l10n,
              const RepoLoadError(RepoFetchErrorKind.network),
            ),
          );
        },
      );

      test('every failing outcome has its own text, an install has none', () {
        final outcomes = <String, PluginInstallOutcome>{
          for (final kind in PluginPackageProblemKind.values)
            'rejected ${kind.name}': PluginInstallRejected(
              PluginPackageProblem(kind),
            ),
          for (final reason in PluginUpdateRefusal.values)
            'refused ${reason.name}': PluginInstallRefused(reason),
          'secrets': const PluginInstallSecretsUnavailable(),
          'gone': const PluginInstallGone(),
        };
        final seen = <String>{};
        for (final MapEntry(:key, :value) in outcomes.entries) {
          final text = pluginOutcomeText(l10n, value);
          expect(text, isNotEmpty, reason: key);
          seen.add(text!);
        }
        expect(seen, hasLength(outcomes.length));
        expect(pluginOutcomeText(l10n, PluginInstalled(recordOf('p'))), isNull);
      });

      test('a repository failure reads like the same file outcome', () {
        for (final kind in PluginPackageProblemKind.values) {
          final problem = PluginPackageProblem(kind, detail: 'x');
          expect(
            repoPluginFailureText(
              l10n,
              RepoPluginFailed(RepoPluginFailure.rejected, problem: problem),
            ),
            pluginOutcomeText(l10n, PluginInstallRejected(problem)),
            reason: kind.name,
          );
        }
        for (final reason in PluginUpdateRefusal.values) {
          expect(
            repoPluginFailureText(
              l10n,
              RepoPluginFailed(RepoPluginFailure.refused, refusal: reason),
            ),
            pluginOutcomeText(l10n, PluginInstallRefused(reason)),
            reason: reason.name,
          );
        }
        expect(
          repoPluginFailureText(
            l10n,
            const RepoPluginFailed(RepoPluginFailure.secretsUnavailable),
          ),
          pluginOutcomeText(l10n, const PluginInstallSecretsUnavailable()),
        );
        expect(
          repoPluginFailureText(
            l10n,
            const RepoPluginFailed(RepoPluginFailure.gone),
          ),
          pluginOutcomeText(l10n, const PluginInstallGone()),
        );
        expect(
          repoPluginFailureText(
            l10n,
            const RepoPluginFailed(RepoPluginFailure.needsNewerApp),
          ),
          pluginProblemText(
            l10n,
            const PluginPackageProblem(PluginPackageProblemKind.needsNewerApp),
          ),
        );
      });

      test('a download failure names the reason', () {
        for (final kind in RepoFetchErrorKind.values) {
          final error = RepoLoadError(kind);
          expect(
            repoPluginFailureText(
              l10n,
              RepoPluginFailed(RepoPluginFailure.download, fetchError: error),
            ),
            l10n.lyricsStoreFailDownload(pluginDownloadReasonText(l10n, error)),
            reason: kind.name,
          );
        }
      });
    });
  }

  final en = locales['en']!;

  test('a rejected package with a detail uses it', () {
    expect(
      pluginProblemText(
        en,
        const PluginPackageProblem(
          PluginPackageProblemKind.scriptError,
          detail: 'lyrics.js',
          line: 12,
        ),
      ),
      en.pluginProblemScriptErrorLine('lyrics.js', 12),
    );
  });

  test('puts the detail into the texts that name it', () {
    String of(PluginPackageProblemKind k, {int? line}) => pluginProblemText(
      en,
      PluginPackageProblem(k, detail: 'THE_DETAIL', line: line),
    );
    for (final kind in [
      PluginPackageProblemKind.unsafeEntry,
      PluginPackageProblemKind.invalidManifest,
      PluginPackageProblemKind.badHost,
      PluginPackageProblemKind.missingScript,
      PluginPackageProblemKind.scriptError,
    ]) {
      expect(of(kind), contains('THE_DETAIL'), reason: kind.name);
    }
    expect(
      of(PluginPackageProblemKind.scriptError, line: 12),
      allOf(contains('THE_DETAIL'), contains('12')),
    );
  });

  test('a manifest problem without a field still reads well', () {
    expect(
      pluginProblemText(
        en,
        const PluginPackageProblem(PluginPackageProblemKind.invalidManifest),
      ),
      en.pluginProblemInvalidManifestPlain,
    );
  });

  test('a locked keyring says to unlock it or restart Kanaru', () {
    expect(
      pluginOutcomeText(en, const PluginInstallSecretsUnavailable()),
      allOf(contains('Unlock the keyring'), contains('restart')),
    );
  });

  test('a rejection or refusal without details falls back to one line', () {
    expect(
      repoPluginFailureText(
        en,
        const RepoPluginFailed(RepoPluginFailure.rejected),
      ),
      en.lyricsStoreFailRejected,
    );
    expect(
      repoPluginFailureText(
        en,
        const RepoPluginFailed(RepoPluginFailure.refused),
      ),
      en.lyricsStoreFailRejected,
    );
  });

  test('needsNewerApp is told apart from other failures', () {
    expect(
      needsNewerApp(const RepoPluginFailed(RepoPluginFailure.needsNewerApp)),
      isTrue,
    );
    expect(
      needsNewerApp(
        const RepoPluginFailed(
          RepoPluginFailure.rejected,
          problem: PluginPackageProblem(PluginPackageProblemKind.needsNewerApp),
        ),
      ),
      isTrue,
    );
    expect(
      needsNewerApp(const RepoPluginFailed(RepoPluginFailure.download)),
      isFalse,
    );
  });
}
