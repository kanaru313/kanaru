import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/m3u/m3u_export_actions.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_nav.dart';
import 'package:kanaru/shared/widgets/library_row.dart' show joinRowDetails;

void main() {
  final l10n = AppLocalizationsEn();

  test('builds one row with a relative-paths trailing button', () {
    final row = m3uExportAction(
      l10n,
      enabled: true,
      exportAbsolute: () {},
      exportRelative: () {},
    );

    expect(row.id, 'export-m3u');
    expect(row.icon, AppIcons.exportFile);
    expect(row.label, l10n.playlistExportM3u);
    expect(row.subtitle, l10n.playlistExportAbsoluteHint);
    expect(row.trailing, hasLength(1));
    expect(row.trailing.single.icon, AppIcons.folderLink);
    expect(row.trailing.single.tooltip, 'Export with relative paths');
  });

  test('appends the detail to the hint', () {
    final row = m3uExportAction(
      l10n,
      enabled: true,
      detail: 'Last played first',
      exportAbsolute: () {},
      exportRelative: () {},
    );

    expect(
      row.subtitle,
      joinRowDetails([l10n.playlistExportAbsoluteHint, 'Last played first']),
    );
  });

  test('a disabled row has no trailing button', () {
    final off = m3uExportAction(
      l10n,
      enabled: false,
      exportAbsolute: () {},
      exportRelative: () {},
    );

    expect(off.enabled, isFalse);
    expect(off.trailing, isEmpty);
  });

  test('the row and the button each close the modal, then export', () {
    final log = <String>[];
    final row = m3uExportAction(
      l10n,
      enabled: true,
      exportAbsolute: () => log.add('absolute'),
      exportRelative: () => log.add('relative'),
    );
    final nav = ContextModalNav(
      push: (_) {},
      pop: () {},
      close: ([_]) => log.add('close'),
    );

    row.onTap!(nav);
    row.trailing.single.onTap(nav);

    expect(log, ['close', 'absolute', 'close', 'relative']);
  });
}
