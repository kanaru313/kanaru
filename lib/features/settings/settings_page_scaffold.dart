import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/page_scaffold.dart';
import 'settings_save_warning.dart';

/// The page frame shared by the Settings root and its section pages: a
/// titled page with a scrolling column of at most 720 px, starting with the
/// warning shown when settings cannot be saved.
class SettingsPageScaffold extends StatelessWidget {
  const SettingsPageScaffold({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Keeps rows readable on wide windows.
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              // Stretched so every section starts at the same left edge,
              // whatever its rows' own width. One column, not a builder, so
              // every row is built.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [const SettingsSaveWarning(), ...children],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
