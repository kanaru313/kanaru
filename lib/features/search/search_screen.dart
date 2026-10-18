import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/empty_state.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: const EmptyState(
        icon: Icons.search,
        title: 'Search your library',
        message: 'Find songs, albums and artists.',
      ),
    );
  }
}
