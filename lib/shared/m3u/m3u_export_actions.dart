import 'package:flutter/widgets.dart' show VoidCallback;

import '../../l10n/app_localizations.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_spec.dart';
import '../widgets/library_row.dart' show joinRowDetails;

/// The two "Export as M3U" rows (absolute, relative paths) of a context modal.
/// [detail] is appended to each hint (e.g. the order). Each row closes the
/// modal, then exports.
List<ContextModalAction> m3uExportActions(
  AppLocalizations l10n, {
  required bool enabled,
  required VoidCallback exportAbsolute,
  required VoidCallback exportRelative,
  String? detail,
}) => [
  ContextModalAction(
    id: 'export-absolute',
    icon: AppIcons.exportFile,
    label: l10n.playlistExportM3u,
    subtitle: joinRowDetails([l10n.playlistExportAbsoluteHint, detail]),
    enabled: enabled,
    onTap: contextModalCloseThen(exportAbsolute),
  ),
  ContextModalAction(
    id: 'export-relative',
    icon: AppIcons.exportFile,
    label: l10n.playlistExportM3u,
    subtitle: joinRowDetails([l10n.playlistExportRelativeHint, detail]),
    enabled: enabled,
    onTap: contextModalCloseThen(exportRelative),
  ),
];
