import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Colour intent for a tally — drives upright + slash colours per theme.
enum TallyVariant { positive, penalty, neutral }

/// The signature Bits Dots Junk motif: a running count drawn as tally marks —
/// groups of five (four uprights + a diagonal slash), rendered in code, never
/// an image. Use it wherever a player's running count appears.
///
/// `count` may be negative; its magnitude is drawn (pair with
/// [TallyVariant.penalty] for points lost).
class TallyMarks extends StatelessWidget {
  const TallyMarks({
    super.key,
    required this.count,
    this.height = 28,
    this.variant = TallyVariant.positive,
    this.uprightColor,
    this.slashColor,
  });

  final int count;
  final double height;
  final TallyVariant variant;

  /// Overrides for special placements (e.g. on an Ink card in light theme).
  final Color? uprightColor;
  final Color? slashColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = count.abs();

    final uprights = uprightColor ??
        (variant == TallyVariant.penalty ? AppTheme.junk(context) : scheme.onSurface);
    final slash = slashColor ??
        (variant == TallyVariant.penalty ? AppTheme.junk(context) : AppTheme.bits(context));

    final h = height;
    final sw = (h * 0.10).clamp(2.0, 11.0);
    final dx = h * 0.26;
    final groupGap = h * 0.46;

    final groups = n ~/ 5;
    final rem = n % 5;

    final uprightXs = <double>[];
    final slashStartXs = <double>[];
    double x = sw;
    for (var g = 0; g < groups; g++) {
      final startX = x;
      for (var k = 0; k < 4; k++) {
        uprightXs.add(x);
        x += dx;
      }
      slashStartXs.add(startX);
      x += groupGap;
    }
    for (var k = 0; k < rem; k++) {
      uprightXs.add(x);
      x += dx;
    }

    final contentRight = uprightXs.isEmpty ? sw : uprightXs.last + sw;
    final width = (contentRight + sw).clamp(h * 0.4, double.infinity);

    return SizedBox(
      width: width,
      height: h,
      child: CustomPaint(
        painter: _TallyPainter(
          uprightXs: uprightXs,
          slashStartXs: slashStartXs,
          dx: dx,
          strokeWidth: sw,
          uprightColor: uprights,
          slashColor: slash,
        ),
      ),
    );
  }
}

class _TallyPainter extends CustomPainter {
  _TallyPainter({
    required this.uprightXs,
    required this.slashStartXs,
    required this.dx,
    required this.strokeWidth,
    required this.uprightColor,
    required this.slashColor,
  });

  final List<double> uprightXs;
  final List<double> slashStartXs;
  final double dx;
  final double strokeWidth;
  final Color uprightColor;
  final Color slashColor;

  @override
  void paint(Canvas canvas, Size size) {
    final top = size.height * 0.12;
    final bottom = size.height * 0.88;

    final upPaint = Paint()
      ..color = uprightColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    for (final x in uprightXs) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), upPaint);
    }

    final slashPaint = Paint()
      ..color = slashColor
      ..strokeWidth = strokeWidth * 1.05
      ..strokeCap = StrokeCap.round;
    for (final sx in slashStartXs) {
      final left = sx - strokeWidth * 0.6;
      final right = sx + dx * 3 + strokeWidth * 0.6;
      canvas.drawLine(Offset(left, bottom), Offset(right, top), slashPaint);
    }
  }

  @override
  bool shouldRepaint(_TallyPainter old) =>
      old.uprightXs != uprightXs ||
      old.slashStartXs != slashStartXs ||
      old.uprightColor != uprightColor ||
      old.slashColor != slashColor ||
      old.strokeWidth != strokeWidth ||
      old.dx != dx;
}
