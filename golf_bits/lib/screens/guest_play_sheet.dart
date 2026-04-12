import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bottom sheet: guest mode trade-offs (Material list + buttons).
class GuestPlaySheet extends StatelessWidget {
  const GuestPlaySheet({
    super.key,
    required this.onContinueGuest,
    required this.onCreateAccountInstead,
  });

  final VoidCallback onContinueGuest;
  final VoidCallback onCreateAccountInstead;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onContinueGuest,
    required VoidCallback onCreateAccountInstead,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => GuestPlaySheet(
        onContinueGuest: onContinueGuest,
        onCreateAccountInstead: onCreateAccountInstead,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.pageHorizontal,
        right: AppTheme.pageHorizontal,
        top: AppTheme.space2,
        bottom: MediaQuery.paddingOf(context).bottom + AppTheme.space6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Play as a guest',
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          SizedBox(height: AppTheme.space2),
          _bullet(context, true, 'Track bits and run rounds.'),
          _bullet(context, true, 'Round history saved on this device.'),
          _bullet(context, false, 'No cross-device history sync.'),
          _bullet(context, false, 'No friend groups or shared history.'),
          SizedBox(height: AppTheme.space6),
          FilledButton(
            onPressed: onContinueGuest,
            child: const Text('Continue as Guest'),
          ),
          SizedBox(height: AppTheme.space3),
          OutlinedButton(
            onPressed: onCreateAccountInstead,
            child: const Text('Create a free account instead'),
          ),
          SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
        ],
      ),
    );
  }

  Widget _bullet(BuildContext context, bool pro, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceHalf),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            pro ? Icons.check_circle : Icons.cancel_outlined,
            color: pro ? scheme.primary : scheme.onSurfaceVariant,
            size: AppTheme.iconInline,
          ),
          SizedBox(width: AppTheme.space3),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
