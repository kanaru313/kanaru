import 'package:material_ui/material_ui.dart';

/// A rounded card container for an individual settings row or tile,
/// separated from neighbouring cards by a 4 px gap (2 px vertical margin).
class SettingCard extends StatelessWidget {
  const SettingCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
  });

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: margin,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
