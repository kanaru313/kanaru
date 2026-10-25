import 'package:material_ui/material_ui.dart';

/// Width of the side pane of a detail page (album, artist) in a wide window.
const detailSidePaneWidth = 320.0;

/// Narrowest page that gets the side pane: the pane plus room for a song
/// list that still shows title, artist and length.
const detailSidePaneMinPageWidth = 840.0;

/// Left column of a detail page in a wide window: [cover] (built
/// [detailSidePaneWidth] wide), fading into the page at its foot and, over
/// a narrow band, to half see-through at its right edge unless [fade] is
/// off, then [details]. It
/// stays put while the content beside it scrolls, and scrolls on its own
/// when the window is too short for it.
class DetailSidePane extends StatelessWidget {
  const DetailSidePane({
    super.key,
    required this.cover,
    required this.details,
    this.fade = true,
  });

  final Widget cover;
  final Widget details;
  final bool fade;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: detailSidePaneWidth,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fade)
              _FadeOut(
                end: Alignment.bottomCenter,
                from: 0.7,
                child: _FadeOut(
                  end: Alignment.centerRight,
                  from: 0.95,
                  edgeOpacity: 0.5,
                  child: cover,
                ),
              )
            else
              cover,
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: details,
            ),
          ],
        ),
      ),
    );
  }
}

/// [child] fully shown from the opposite edge up to [from] (a share of the
/// way towards [end]), then fading out to [edgeOpacity] at [end] (fully
/// transparent by default), so the cover melts into the page there.
class _FadeOut extends StatelessWidget {
  const _FadeOut({
    required this.end,
    required this.from,
    required this.child,
    this.edgeOpacity = 0,
  });

  final Alignment end;
  final double from;
  final double edgeOpacity;
  final Widget child;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (bounds) => LinearGradient(
      begin: -end,
      end: end,
      stops: [0, from, 1],
      colors: [
        const Color(0xFFFFFFFF),
        const Color(0xFFFFFFFF),
        const Color(0xFFFFFFFF).withValues(alpha: edgeOpacity),
      ],
    ).createShader(bounds),
    child: child,
  );
}
