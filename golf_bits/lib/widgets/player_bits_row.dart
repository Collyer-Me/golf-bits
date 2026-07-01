import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'award_bits_button.dart';
import 'tally_marks.dart';

/// Bits tally (this hole), running total, and award control — score and + stay right-aligned.
class PlayerBitsRow extends StatelessWidget {
  const PlayerBitsRow({
    super.key,
    required this.totalBits,
    required this.onAward,
    this.holeBits = 0,
    this.tallyHeight = 22,
  });

  /// Running round total (numeral on the right).
  final int totalBits;
  /// Bits awarded on the current hole only (tally marks on the left).
  final int holeBits;
  final VoidCallback onAward;
  final double tallyHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalStr = totalBits >= 0 ? '+$totalBits' : '$totalBits';
    final scoreColor = totalBits > 0
        ? AppTheme.bits(context)
        : totalBits < 0
            ? AppTheme.junk(context)
            : scheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: holeBits == 0
                ? Text(
                    '—',
                    style: AppTheme.score(context, size: 16, color: scheme.onSurfaceVariant),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: TallyMarks(
                      count: holeBits,
                      height: tallyHeight,
                      variant: holeBits < 0 ? TallyVariant.penalty : TallyVariant.positive,
                    ),
                  ),
          ),
        ),
        Text(totalStr, style: AppTheme.score(context, size: 26, color: scoreColor)),
        SizedBox(width: AppTheme.space2),
        AwardBitsButton(onPressed: onAward),
      ],
    );
  }
}
