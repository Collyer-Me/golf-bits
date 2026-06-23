import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'tally_marks.dart';

/// Gentle tilt + vertical bob for welcome preview cards (design `bdjFloat`).
class WelcomeFloatingPreview extends StatefulWidget {
  const WelcomeFloatingPreview({
    super.key,
    required this.child,
    this.tiltDegrees = AppTheme.welcomePreviewTilt,
    this.floatAmplitude = AppTheme.welcomePreviewFloat,
    this.duration = AppTheme.welcomePreviewFloatDuration,
  });

  final Widget child;
  final double tiltDegrees;
  final double floatAmplitude;
  final Duration duration;

  @override
  State<WelcomeFloatingPreview> createState() => _WelcomeFloatingPreviewState();
}

class _WelcomeFloatingPreviewState extends State<WelcomeFloatingPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _offsetY;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _offsetY = _buildOffsetAnimation();
  }

  Animation<double> _buildOffsetAnimation() => Tween<double>(
        begin: 0,
        end: -widget.floatAmplitude,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animating || MediaQuery.disableAnimationsOf(context)) return;
    _animating = true;
    _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(WelcomeFloatingPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.floatAmplitude != widget.floatAmplitude) {
      _offsetY = _buildOffsetAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tilt = widget.tiltDegrees * pi / 180;
    if (MediaQuery.disableAnimationsOf(context)) {
      return Transform.rotate(angle: tilt, child: widget.child);
    }

    return AnimatedBuilder(
      animation: _offsetY,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _offsetY.value),
        child: Transform.rotate(angle: tilt, child: child),
      ),
      child: widget.child,
    );
  }
}

/// Decorative onboarding previews — not interactive. Built from the same tokens
/// as production UI so the welcome carousel stays in sync with the design system.
enum WelcomeDemoPlayer { alex, sam, you }

extension WelcomeDemoPlayerColors on WelcomeDemoPlayer {
  Color get fill => switch (this) {
        WelcomeDemoPlayer.alex => AppColors.fairway,
        WelcomeDemoPlayer.sam => AppColors.sandWinner,
        WelcomeDemoPlayer.you => AppColors.pine,
      };

  Color get onFill => switch (this) {
        WelcomeDemoPlayer.you => AppColors.parchment,
        _ => AppColors.ink,
      };

  String get initial => switch (this) {
        WelcomeDemoPlayer.alex => 'A',
        WelcomeDemoPlayer.sam => 'S',
        WelcomeDemoPlayer.you => 'Y',
      };

  String get label => switch (this) {
        WelcomeDemoPlayer.alex => 'Alex',
        WelcomeDemoPlayer.sam => 'Sam',
        WelcomeDemoPlayer.you => 'You',
      };
}

/// Parchment preview card shell used on the dark welcome carousel.
class WelcomePreviewCard extends StatelessWidget {
  const WelcomePreviewCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space4,
        AppTheme.space4,
        AppTheme.space4,
        AppTheme.space3,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightRaised,
        borderRadius: BorderRadius.circular(AppTheme.welcomePreviewRadius),
        boxShadow: AppTheme.welcomePreviewCardShadow(),
      ),
      child: DefaultTextStyle(
        style: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          height: 1.2,
        ),
        child: child,
      ),
    );
  }
}

/// Slide 1 — live scorecard with tally marks.
class WelcomeScorecardPreview extends StatelessWidget {
  const WelcomeScorecardPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WelcomePreviewCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _previewHeader(
            left: 'SATURDAY · ROYAL PINES',
            right: '7/18',
            rightColor: AppColors.sandWinnerText,
          ),
          _scoreRow(
            player: WelcomeDemoPlayer.alex,
            bits: 8,
            tallyVariant: TallyVariant.positive,
          ),
          _scoreRow(
            player: WelcomeDemoPlayer.sam,
            bits: 3,
            tallyVariant: TallyVariant.positive,
          ),
          _scoreRow(
            player: WelcomeDemoPlayer.you,
            bits: -2,
            tallyVariant: TallyVariant.penalty,
          ),
        ],
      ),
    );
  }
}

/// Slide 2 — award chip grid.
class WelcomeAwardChipsPreview extends StatelessWidget {
  const WelcomeAwardChipsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WelcomePreviewCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _previewHeader(left: 'AWARD TO ALEX · HOLE 7'),
          const SizedBox(height: AppTheme.space3),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: const [
              _EventPreviewChip(label: 'Sandie', delta: '+2', style: _EventChipStyle.subtlePositive),
              _EventPreviewChip(label: 'Greenie', delta: '+1', style: _EventChipStyle.subtlePositive),
              _EventPreviewChip(label: 'Eagle', delta: '+5', style: _EventChipStyle.sand),
              _EventPreviewChip(label: 'Three-putt', delta: '−1', style: _EventChipStyle.penalty),
            ],
          ),
        ],
      ),
    );
  }
}

/// Slide 3 — settle-up summary.
class WelcomeSettleUpPreview extends StatelessWidget {
  const WelcomeSettleUpPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WelcomePreviewCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _previewHeader(
            left: 'SETTLE UP · \$2 / BIT',
            right: 'POT \$28',
            rightColor: AppColors.sandWinnerText,
          ),
          _settleRow(
            player: WelcomeDemoPlayer.sam,
            text: TextSpan(
              children: [
                const TextSpan(text: 'Sam pays '),
                TextSpan(
                  text: 'Alex',
                  style: TextStyle(color: AppColors.bitsPositiveLight),
                ),
              ],
            ),
            amount: '\$10',
            amountColor: AppColors.ink,
          ),
          _settleRow(
            player: WelcomeDemoPlayer.you,
            text: TextSpan(
              children: [
                const TextSpan(text: 'You pay '),
                TextSpan(
                  text: 'Alex',
                  style: TextStyle(color: AppColors.bitsPositiveLight),
                ),
              ],
            ),
            amount: '\$8',
            amountColor: AppColors.ink,
          ),
          _settleRow(
            player: WelcomeDemoPlayer.alex,
            text: const TextSpan(text: 'Alex collects'),
            amount: '+\$18',
            amountColor: AppColors.bitsPositiveLight,
          ),
        ],
      ),
    );
  }
}

Widget _previewHeader({
  required String left,
  String? right,
  Color? rightColor,
}) {
  final label = GoogleFonts.dmMono(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.6,
    color: AppColors.lightMuted,
  );
  return Padding(
    padding: const EdgeInsets.only(bottom: AppTheme.space3),
    child: Row(
      children: [
        Expanded(child: Text(left.toUpperCase(), style: label)),
        if (right != null)
          Text(
            right,
            style: label.copyWith(
              letterSpacing: 0.6,
              color: rightColor ?? AppColors.lightMuted,
            ),
          ),
      ],
    ),
  );
}

Widget _playerAvatar(WelcomeDemoPlayer player, {double size = 32}) {
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: player.fill,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      player.initial,
      style: GoogleFonts.bricolageGrotesque(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: player.onFill,
        height: 1,
      ),
    ),
  );
}

Widget _previewDivider() => Divider(
      height: 1,
      thickness: 1,
      color: AppColors.ink.withValues(alpha: AppTheme.opacityWelcomeInkHairline),
    );

Widget _scoreRow({
  required WelcomeDemoPlayer player,
  required int bits,
  required TallyVariant tallyVariant,
}) {
  final scoreColor = bits > 0
      ? AppColors.bitsPositiveLight
      : bits < 0
          ? AppColors.junkPenaltyText
          : AppColors.ink;
  final scoreText = bits >= 0 ? '+$bits' : '$bits';

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _previewDivider(),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space2),
        child: Row(
          children: [
            _playerAvatar(player),
            const SizedBox(width: 11),
            SizedBox(width: 40, child: Text(player.label)),
            Expanded(
              child: TallyMarks(
                count: bits.abs(),
                height: 22,
                variant: tallyVariant,
                uprightColor:
                    tallyVariant == TallyVariant.penalty ? AppColors.junkPenalty : AppColors.ink,
                slashColor:
                    tallyVariant == TallyVariant.penalty ? AppColors.junkPenalty : AppColors.fairway,
              ),
            ),
            Text(
              scoreText,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: scoreColor,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _settleRow({
  required WelcomeDemoPlayer player,
  required InlineSpan text,
  required String amount,
  required Color amountColor,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _previewDivider(),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            _playerAvatar(player),
            const SizedBox(width: 11),
            Expanded(child: Text.rich(text)),
            Text(
              amount,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: amountColor,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

enum _EventChipStyle { positive, subtlePositive, sand, penalty, dashed }

class _EventPreviewChip extends StatelessWidget {
  const _EventPreviewChip({
    required this.label,
    this.delta,
    required this.style,
  });

  final String label;
  final String? delta;
  final _EventChipStyle style;

  @override
  Widget build(BuildContext context) {
    final deltaStyle = GoogleFonts.dmMono(
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
      height: 1,
    );

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (delta != null) ...[
          const SizedBox(width: 6),
          Text(delta!, style: deltaStyle),
        ],
      ],
    );

    final base = GoogleFonts.hankenGrotesk(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      height: 1,
    );

    final radius = BorderRadius.circular(AppTheme.stadiumRadius);

    switch (style) {
      case _EventChipStyle.positive:
        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(color: AppColors.fairway, borderRadius: radius),
          alignment: Alignment.center,
          child: DefaultTextStyle(
            style: base.copyWith(color: AppColors.ink),
            child: child,
          ),
        );
      case _EventChipStyle.subtlePositive:
        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: AppColors.fairway.withValues(alpha: AppTheme.opacityFairwayChipFill),
            borderRadius: radius,
            border: Border.all(
              color: AppColors.fairway.withValues(alpha: AppTheme.opacityFairwayChipBorder),
            ),
          ),
          alignment: Alignment.center,
          child: DefaultTextStyle(
            style: base.copyWith(color: AppColors.bitsPositiveLight),
            child: child,
          ),
        );
      case _EventChipStyle.sand:
        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(color: AppColors.sandWinner, borderRadius: radius),
          alignment: Alignment.center,
          child: DefaultTextStyle(
            style: base.copyWith(color: AppColors.ink),
            child: child,
          ),
        );
      case _EventChipStyle.penalty:
        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: AppColors.junkPenalty.withValues(alpha: AppTheme.opacityJunkChipFill),
            borderRadius: radius,
            border: Border.all(
              color: AppColors.junkPenalty.withValues(alpha: AppTheme.opacityJunkChipBorder),
            ),
          ),
          alignment: Alignment.center,
          child: DefaultTextStyle(
            style: base.copyWith(color: AppColors.junkPenaltyText),
            child: child,
          ),
        );
      case _EventChipStyle.dashed:
        return CustomPaint(
          painter: _DashedPillBorderPainter(
            color: AppColors.ink.withValues(alpha: AppTheme.opacityInkDashedBorder),
            radius: AppTheme.stadiumRadius,
          ),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            alignment: Alignment.center,
            child: DefaultTextStyle(
              style: base.copyWith(color: AppColors.lightMuted),
              child: child,
            ),
          ),
        );
    }
  }
}

class _DashedPillBorderPainter extends CustomPainter {
  _DashedPillBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 5;
        final extract = metric.extractPath(distance, next.clamp(0, metric.length));
        canvas.drawPath(extract, paint);
        distance = next + 4;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillBorderPainter oldDelegate) => oldDelegate.color != color;
}
