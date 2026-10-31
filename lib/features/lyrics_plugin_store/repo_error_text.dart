import '../../core/lyrics/plugins/repo/plugin_repo.dart';
import '../../core/lyrics/plugins/repo/repo_address_rules.dart';
import '../../core/lyrics/plugins/repo/repo_fetch_exception.dart';
import '../../core/lyrics/plugins/repo/repo_operation_results.dart';
import '../../l10n/l10n.dart';

/// Why a repository's last fetch failed, as a short phrase ("lỗi mạng").
String repoLoadReasonText(AppLocalizations l10n, RepoLoadError error) =>
    switch (error.kind) {
      RepoFetchErrorKind.network => l10n.lyricsStoreLoadNetwork,
      RepoFetchErrorKind.notFound => l10n.lyricsStoreLoadNotFound,
      RepoFetchErrorKind.tooLarge => l10n.lyricsStoreLoadTooLarge,
      RepoFetchErrorKind.invalidCatalog => l10n.lyricsStoreLoadInvalid,
      RepoFetchErrorKind.blockedAddress => l10n.lyricsStoreLoadBlocked,
    };

/// Why a package download failed, as a short phrase.
String downloadReasonText(AppLocalizations l10n, RepoLoadError error) =>
    error.kind == RepoFetchErrorKind.tooLarge
    ? l10n.lyricsStoreFailPackageTooLarge
    : repoLoadReasonText(l10n, error);

/// The rule that refused an address, as a short phrase.
String addressProblemText(
  AppLocalizations l10n,
  RepoAddressProblem problem,
) => switch (problem) {
  RepoAddressProblem.invalidUrl => l10n.lyricsStoreAddErrInvalidUrl,
  RepoAddressProblem.userInfo => l10n.lyricsStoreAddressUserInfo,
  RepoAddressProblem.publicNeedsHttps => l10n.lyricsStoreAddErrPublicNeedsHttps,
  RepoAddressProblem.localFromPublic => l10n.lyricsStoreAddressLocalFromPublic,
  RepoAddressProblem.refusedAddress => l10n.lyricsStoreAddressRefused,
  RepoAddressProblem.mixedAddresses => l10n.lyricsStoreAddressMixed,
  RepoAddressProblem.localNameOnPublic =>
    l10n.lyricsStoreAddressLocalNamePublic,
};

/// The text under the URL field for a failed add.
String addRepoFailureText(AppLocalizations l10n, AddRepoFailed failed) =>
    switch (failed.failure) {
      AddRepoFailure.invalidUrl => l10n.lyricsStoreAddErrInvalidUrl,
      AddRepoFailure.publicNeedsHttps => l10n.lyricsStoreAddErrPublicNeedsHttps,
      AddRepoFailure.duplicate => l10n.lyricsStoreAddErrDuplicate,
      AddRepoFailure.network => l10n.lyricsStoreAddErrNetwork,
      AddRepoFailure.notFound => l10n.lyricsStoreAddErrNotFound,
      AddRepoFailure.badFormat => l10n.lyricsStoreAddErrBadFormat,
      AddRepoFailure.blockedAddress =>
        failed.addressProblem == null
            ? l10n.lyricsStoreAddErrBlocked
            : l10n.lyricsStoreAddErrBlockedReason(
                addressProblemText(l10n, failed.addressProblem!),
              ),
      AddRepoFailure.storage => l10n.lyricsStoreAddErrStorage,
    };
