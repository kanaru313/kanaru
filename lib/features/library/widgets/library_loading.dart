import 'package:material_ui/material_ui.dart';

/// The spinner of library pages while their first result loads.
class LibraryLoading extends StatelessWidget {
  const LibraryLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox.square(
      dimension: 28,
      child: CircularProgressIndicator(strokeWidth: 3),
    ),
  );
}
