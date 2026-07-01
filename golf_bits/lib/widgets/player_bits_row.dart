import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'award_bits_button.dart';
import 'tally_marks.dart';

/// Bits tally, running total, and award control on one line (hole scoring design).
class PlayerBitsRow extends StatelessWidget {
  const PlayerBitsRow({
    super.key,
    required this.totalBits,
    required this.onAward,
    this.holeBits = 0,
    this.tallyHeight = 22,
  });

  final int totalBits;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: TallyMarks(
                  count: totalBits,
                  height: tallyHeight,
                  variant: totalBits < 0 ? TallyVariant.penalty : TallyVariant.positive,
                ),
              ),
            ),
            const Spacer(),
            Text(totalStr, style: AppTheme.score(context, size: 26, color: scoreColor)),
            SizedBox(width: AppTheme.space3),
            AwardBitsButton(onPressed: onAward),
          ],
        ),
        if (holeBits != 0)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.space1),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${holeBits >= 0 ? '+$holeBits' : '$holeBits'} this hole',
                style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
      ],
    );
  }
}
