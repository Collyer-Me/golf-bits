import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HoleFooterNav extends StatelessWidget {
  const HoleFooterNav({
    super.key,
    required this.onPrevious,
    required this.onNext,
    this.previousEnabled = true,
    this.nextLabel = 'Next hole',
    this.leading,
  });

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool previousEnabled;
  final String nextLabel;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: AppTheme.space2),
        ] else if (onPrevious != null)
          IconButton.outlined(
            tooltip: 'Previous hole',
            onPressed: previousEnabled ? onPrevious : null,
            icon: const Icon(Icons.arrow_back),
          ),
        if (onPrevious != null || leading != null) const SizedBox(width: AppTheme.space2),
        Expanded(
          child: FilledButton(
            onPressed: onNext,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(nextLabel),
                const SizedBox(width: AppTheme.space2),
                const Icon(Icons.arrow_forward, size: AppTheme.iconArrow),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
