import '../../l10n/l10n.dart';

/// [bytes] as a short size in the user's language: bytes below 1 KB, then KB,
/// then MB.
String pluginSizeText(AppLocalizations l10n, int bytes) {
  if (bytes < 1024) return l10n.settingsUnitBytes(bytes);
  final kb = bytes / 1024;
  return kb < 1024
      ? l10n.settingsUnitKb(kb.round())
      : l10n.settingsUnitMb(kb / 1024);
}
