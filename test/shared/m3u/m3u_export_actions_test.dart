import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/m3u/m3u_export_actions.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_nav.dart';
import 'package:kanaru/shared/widgets/library_row.dart' show joinRowDetails;

void main() {
  final l10n = AppLocalizationsEn();

  test('builds the absolute and relative rows', () {
    final rows = m3uExportActions(
      l10n,
      enabled: true,
      exportAbsolute: () {},
      exportRelative: () {},
    );

    expect(
      [for (final r in rows) r.id],
      ['export-absolute', 'export-relative'],
    );
    expect(rows.every((r) => r.icon == AppIcons.exportFile), isTrue);
    expect(rows.every((r) => r.label == l10n.playlistExportM3u), isTrue);
    expect(rows[0].subtitle, l10n.playlistExportAbsoluteHint);
    expect(rows[1].subtitle, l10n.playlistExportRelativeHint);
  });

  test('appends the detail to each hint', () {
    final rows = m3uExportActions(
      l10n,
      enabled: true,
      detail: 'Last played first',
      exportAbsolute: () {},
      exportRelative: () {},
    );

    expect(
      rows[0].subtitle,
      equals(
        joinRowDetails([l10n.playlistExportAbsoluteHint, 'Last played first']),
      ),
    );
    expect(
      rows[1].subtitle,
      equals(
        joinRowDetails([l10n.playlistExportRelativeHint, 'Last played first']),
      ),
    );
  });

  test('both rows follow enabled', () {
    final off = m3uExportActions(
      l10n,
      enabled: false,
      exportAbsolute: () {},
      exportRelative: () {},
    );

    expect(off.every((r) => !r.enabled), isTrue);
  });

  test('each row closes the modal, then exports', () {
    final log = <String>[];
    final rows = m3uExportActions(
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

    rows[0].onTap!(nav);
    rows[1].onTap!(nav);

    expect(log, ['close', 'absolute', 'close', 'relative']);
  });
}
