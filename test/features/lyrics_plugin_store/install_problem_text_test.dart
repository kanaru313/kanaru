import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_problem.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_install_outcome.dart';
import 'package:kanaru/features/lyrics_plugin_store/install_problem_text.dart';
import 'package:kanaru/features/lyrics_plugin_store/repo_error_text.dart';

import 'store_test_harness.dart';

void main() {
  for (final l10n in [en, vi]) {
    group('texts in ${l10n.localeName}', () {
      test('every package problem kind has a text', () {
        for (final kind in PluginPackageProblemKind.values) {
          final text = packageProblemText(
            l10n,
            PluginPackageProblem(kind, detail: 'x', line: 3),
          );
          expect(text, isNotEmpty, reason: kind.name);
        }
      });

      test('every install failure has a text', () {
        for (final failure in RepoPluginFailure.values) {
          expect(
            repoFailureText(l10n, RepoPluginFailed(failure)),
            isNotEmpty,
            reason: failure.name,
          );
        }
      });

      test('every load error and address rule has a text', () {
        for (final kind in RepoFetchErrorKind.values) {
          expect(repoLoadReasonText(l10n, RepoLoadError(kind)), isNotEmpty);
        }
        for (final problem in RepoAddressProblem.values) {
          expect(addressProblemText(l10n, problem), isNotEmpty);
        }
      });

      test('every file outcome except success has a text', () {
        final outcomes = <PluginInstallOutcome>[
          const PluginInstallRejected(
            PluginPackageProblem(PluginPackageProblemKind.notZip),
          ),
          for (final reason in PluginUpdateRefusal.values)
            PluginInstallRefused(reason),
          const PluginInstallSecretsUnavailable(),
          const PluginInstallGone(),
        ];
        for (final outcome in outcomes) {
          expect(fileOutcomeText(l10n, outcome), isNotEmpty);
        }
        expect(fileOutcomeText(l10n, PluginInstalled(recordOf('p'))), isNull);
      });
    });
  }

  test('a rejected package with a detail uses it', () {
    expect(
      packageProblemText(
        en,
        const PluginPackageProblem(
          PluginPackageProblemKind.scriptError,
          detail: 'lyrics.js',
          line: 12,
        ),
      ),
      'The script lyrics.js has an error on line 12',
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
