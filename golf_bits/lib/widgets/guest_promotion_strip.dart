import 'package:flutter/material.dart';

import '../screens/guest_upgrade_screen.dart';
import '../theme/app_theme.dart';
import '../auth/guest_promotion.dart';

/// Dense dismissible strip: guest sync nudge + upgrade action (e.g. dashboard).
class GuestPromotionStrip extends StatelessWidget {
  const GuestPromotionStrip({
    super.key,
    required this.onDismiss,
  });

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3, vertical: AppTheme.space2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.person_off_outlined, size: AppTheme.iconDense, color: scheme.onSurfaceVariant),
            SizedBox(width: AppTheme.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    GuestPromotionCopy.syncShortLine,
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                  ),
                  SizedBox(height: AppTheme.space2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(builder: (_) => const GuestUpgradeScreen()),
                        );
                      },
                      child: Text(GuestPromotionCopy.upgradeCta),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
