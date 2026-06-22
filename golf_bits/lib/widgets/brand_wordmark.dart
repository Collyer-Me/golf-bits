import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// The Bits Dots Junk logo mark: four Parchment tally strokes + a Fairway slash
/// on an Ink rounded square. Drawn in code (mirrors `logo-mark.svg`). The mark
/// keeps its Ink square in both themes so the Parchment strokes stay legible.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BrandMarkPainter()),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.2));
    canvas.drawRRect(rect, Paint()..color = AppColors.ink);

    final top = s * 0.195;
    final bottom = s * 0.805;
    final uprights = Paint()
      ..color = AppColors.parchment
      ..strokeWidth = s * 0.062
      ..strokeCap = StrokeCap.round;
    for (final f in const [0.2375, 0.4125, 0.5875, 0.7625]) {
      canvas.drawLine(Offset(f * s, top), Offset(f * s, bottom), uprights);
    }

    final slash = Paint()
      ..color = AppColors.fairway
      ..strokeWidth = s * 0.075
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s * 0.17, s * 0.86), Offset(s * 0.86, s * 0.19), slash);
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) => false;
}

enum BrandWordmarkSize { hero, screen, compact }

/// Logo mark paired with the "Bits Dots Junk" wordmark in Bricolage Grotesque.
/// Pass [markOnly] for a compact brand cue (e.g. a secondary app bar).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.size = BrandWordmarkSize.hero,
    this.markOnly = false,
  });

  final BrandWordmarkSize size;
  final bool markOnly;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final (double markSize, double fontSize) = switch (size) {
      BrandWordmarkSize.hero => (56.0, 30.0),
      BrandWordmarkSize.screen => (34.0, 22.0),
      BrandWordmarkSize.compact => (26.0, 18.0),
    };

    final mark = BrandMark(size: markSize);
    if (markOnly) {
      return Semantics(label: 'Bits Dots Junk', image: true, child: mark);
    }

    return Semantics(
      label: 'Bits Dots Junk',
      header: true,
      child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: markSize * 0.32),
        Flexible(
          child: Text(
            'Bits Dots Junk',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.0,
              color: color,
            ),
          ),
        ),
      ],
    ),
    );
  }
}
