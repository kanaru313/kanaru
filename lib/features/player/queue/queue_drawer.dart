import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'queue_panel.dart';

/// Widest the queue drawer gets.
const queueDrawerWidth = 400.0;

/// The queue panel as a drawer from the right edge, for a Scaffold's
/// `endDrawer`. At most 90% of the window wide.
class QueueDrawer extends StatelessWidget {
  const QueueDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: min(queueDrawerWidth, MediaQuery.sizeOf(context).width * 0.9),
      child: const SafeArea(child: QueuePanel()),
    );
  }
}
