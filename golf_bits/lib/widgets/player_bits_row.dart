import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'award_bits_button.dart';
import 'tally_marks.dart';

/// Round-total tally marks, this-hole numeric score, and award control.
class PlayerBitsRow extends StatelessWidget {
  const PlayerBitsRow({
    super.key,
    required this.totalBits,
    required this.onAward,
    this.holeBits = 0,
    this.tallyHeight = 22,
  });

  /// Running round total (tally marks on the left).
  final int totalBits;
  /// Bits awarded on the current hole only (numeric on the right).
  final int holeBits;
  final VoidCallback onAward;
  final double tallyHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final holeStr = holeBits == 0
        ? '—'
        : holeBits > 0
            ? '+$holeBits'
            : '$holeBits';
    final holeColor = holeBits > 0
        ? AppTheme.bits(context)
        : holeBits < 0
            ? AppTheme.junk(context)
            : scheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: totalBits == 0
                ? Text(
                    '—',
                    style: AppTheme.score(context, size: 16, color: scheme.onSurfaceVariant),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: TallyMarks(
                      count: totalBits,
                      height: tallyHeight,
                      variant: totalBits < 0 ? TallyVariant.penalty : TallyVariant.positive,
                    ),
                  ),
          ),
        ),
        Text(holeStr, style: AppTheme.score(context, size: 22, color: holeColor)),
        SizedBox(width: AppTheme.space2),
        AwardBitsButton(onPressed: onAward),
      ],
    );
  }
}
