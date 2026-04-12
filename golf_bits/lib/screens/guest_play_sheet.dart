import 'package:flutter/material.dart';

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
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 24,
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
          const SizedBox(height: 8),
          _bullet(context, true, 'Track bits and run rounds.'),
          _bullet(context, true, 'Round history saved on this device.'),
          _bullet(context, false, 'No cross-device history sync.'),
          _bullet(context, false, 'No friend groups or shared history.'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onContinueGuest,
            child: const Text('Continue as Guest'),
          ),
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            pro ? Icons.check_circle : Icons.cancel_outlined,
            color: pro ? scheme.primary : scheme.onSurfaceVariant,
            size: 22,
          ),
          const SizedBox(width: 12),
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
