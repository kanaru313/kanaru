import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/empty_state.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      body: const EmptyState(
        icon: Icons.queue_music_outlined,
        title: 'No playlists yet',
        message: 'Playlists you create will show up here.',
      ),
    );
  }
}
