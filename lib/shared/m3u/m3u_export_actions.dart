import 'package:flutter/widgets.dart' show VoidCallback;

import '../../l10n/app_localizations.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_spec.dart';
import '../widgets/library_row.dart' show joinRowDetails;

/// The "Export as M3U" row of a context modal: the row writes absolute paths,
/// its trailing folder-link button writes relative ones. [detail] is appended
/// to the hint (e.g. the order). Both close the modal, then export. While the
/// row is not [enabled] it has no trailing button, since a trailing button
/// has no disabled state of its own.
ContextModalAction m3uExportAction(
  AppLocalizations l10n, {
  required bool enabled,
  required VoidCallback exportAbsolute,
  required VoidCallback exportRelative,
  String? detail,
}) => ContextModalAction(
  id: 'export-m3u',
  icon: AppIcons.exportFile,
  label: l10n.playlistExportM3u,
  subtitle: joinRowDetails([l10n.playlistExportAbsoluteHint, detail]),
  enabled: enabled,
  onTap: contextModalCloseThen(exportAbsolute),
  trailing: [
    if (enabled)
      ContextModalTrailing(
        icon: AppIcons.folderLink,
        tooltip: l10n.m3uExportRelativeTooltip,
        onTap: contextModalCloseThen(exportRelative),
      ),
  ],
);
