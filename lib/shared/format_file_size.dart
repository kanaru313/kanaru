import 'package:intl/intl.dart';

import '../l10n/l10n.dart';

/// [bytes] as a short size: bytes below 1 KB, whole KB, then MB and GB with
/// at most one decimal, in the app's language. A unit is left for the next
/// one as soon as it would round to 1024 (so never "1024 KB").
String formatFileSize(AppLocalizations l10n, int bytes) {
  if (bytes < 1024) return l10n.settingsUnitBytes(bytes);
  final kb = (bytes / 1024).round();
  if (kb < 1024) return l10n.settingsUnitKb(kb);
  final number = NumberFormat('#,##0.#', l10n.localeName);
  final mb = double.parse((bytes / 1048576).toStringAsFixed(1));
  if (mb < 1024) return l10n.songInfoFileSizeMb(number.format(mb));
  final gb = bytes / 1073741824;
  return l10n.songInfoFileSizeGb(number.format(gb));
}
