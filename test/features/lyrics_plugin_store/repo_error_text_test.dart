import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_repo.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';
import 'package:kanaru/features/lyrics_plugin_store/repo_error_text.dart';

import 'store_test_harness.dart';

void main() {
  for (final l10n in [en, vi]) {
    test(
      'every load error and address rule has a text in ${l10n.localeName}',
      () {
        for (final kind in RepoFetchErrorKind.values) {
          expect(repoLoadReasonText(l10n, RepoLoadError(kind)), isNotEmpty);
        }
        for (final problem in RepoAddressProblem.values) {
          expect(addressProblemText(l10n, problem), isNotEmpty);
        }
      },
    );
  }
}
