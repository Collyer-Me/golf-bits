import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'player_colors.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.displayName,
    required this.colorIndex,
    this.size = 38,
  });

  final String displayName;
  final int colorIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fill = playerColorForIndex(context, colorIndex);
    final onFill = playerOnColorForFill(context, fill);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppTheme.avatarRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        initialForDisplayName(displayName),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: onFill,
            ),
      ),
    );
  }
}
