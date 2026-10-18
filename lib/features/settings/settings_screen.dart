import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/empty_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const EmptyState(
        icon: Icons.settings_outlined,
        title: 'Settings',
        message: 'Nothing to configure yet.',
      ),
    );
  }
}
