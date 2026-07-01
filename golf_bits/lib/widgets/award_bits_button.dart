import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Compact circular control to open the bits award sheet.
class AwardBitsButton extends StatelessWidget {
  const AwardBitsButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Award bits',
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppTheme.awardButtonSize, AppTheme.awardButtonSize),
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        child: const Icon(Icons.add, size: AppTheme.iconDense),
      ),
    );
  }
}
