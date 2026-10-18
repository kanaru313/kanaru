import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/empty_state.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: const EmptyState(
        icon: Icons.library_music_outlined,
        title: 'Your library is empty',
        message: 'Add a music folder to start building your library.',
      ),
    );
  }
}
