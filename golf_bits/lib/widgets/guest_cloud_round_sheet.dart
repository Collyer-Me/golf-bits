import 'package:flutter/material.dart';

import '../screens/sign_up_screen.dart';
import '../theme/app_theme.dart';

/// Shown once per app session before creating a cloud round without a session.
abstract final class GuestCloudRoundConsent {
  static bool _sessionAcknowledged = false;

  static bool get sessionAcknowledged => _sessionAcknowledged;

  static void resetSessionForTests() {
    _sessionAcknowledged = false;
  }

  /// Returns true if the user chose to continue as an anonymous cloud session.
  static Future<bool> ensureAcknowledged(BuildContext context) async {
    if (_sessionAcknowledged) return true;
    final result = await GuestCloudRoundSheet.show(context);
    if (result == true) _sessionAcknowledged = true;
    return result == true;
  }
}

/// Explains guest cloud save before [signInAnonymously] for round sync.
class GuestCloudRoundSheet extends StatelessWidget {
  const GuestCloudRoundSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => const GuestCloudRoundSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

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
                  'Save this round to the cloud?',
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          SizedBox(height: AppTheme.space2),
          Text(
            'Without signing in, we will start a guest profile in this browser so your round can sync and resume.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          SizedBox(height: AppTheme.space5),
          _bullet(context, true, 'Track bits and save round progress to the server.'),
          _bullet(context, true, 'Resume this round on this browser.'),
          _bullet(context, false, 'Limited to this browser until you upgrade your guest account.'),
          SizedBox(height: AppTheme.space6),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue as guest'),
          ),
          SizedBox(height: AppTheme.space3),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
              );
            },
            child: const Text('Create a free account first'),
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
            pro ? Icons.check_circle : Icons.info_outline,
            color: pro ? scheme.primary : scheme.onSurfaceVariant,
            size: AppTheme.iconInline,
          ),
          SizedBox(width: AppTheme.space3),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
