import 'package:material_ui/material_ui.dart';

/// Gives a library page its own (transparent) [Material]. The Albums and
/// Artists branches push detail pages, and the page transition paints a
/// background between a page and the shell's [Material], which would hide
/// the ink of list rows.
class PageMaterial extends StatelessWidget {
  const PageMaterial({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Material(type: MaterialType.transparency, child: child);
}
