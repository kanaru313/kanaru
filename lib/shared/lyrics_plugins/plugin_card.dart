import 'package:material_ui/material_ui.dart';

/// A rounded, elevation-free card container for plugin detail pages and sections.
class PluginCard extends StatelessWidget {
  const PluginCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: margin,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: padding == null
          ? child
          : Padding(padding: padding!, child: child),
    );
  }
}
