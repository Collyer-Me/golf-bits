import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../data/history_repository.dart';
import 'pending_auth_link.dart';

/// Ensures a signed-in user has a profile row in `public.profiles`.
abstract final class ProfileBootstrap {
  static Future<void> ensureCurrentUserProfile() async {
    if (!SupabaseEnv.isConfigured) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final fullName = (user.userMetadata?['full_name'] as String?)?.trim();
    final fallbackName = user.email?.split('@').first.trim();
    final displayName = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : ((fallbackName != null && fallbackName.isNotEmpty) ? fallbackName : 'Player');

    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'display_name': displayName,
        if (user.email != null && user.email!.trim().isNotEmpty) 'email': user.email!.trim(),
      });
    } on PostgrestException catch (_) {
      // Profile sync should not block successful auth.
    }

    try {
      await HistoryRepository.claimParticipantIdentityForCurrentUser();
    } catch (_) {
      // Link saved-round participant rows by email when profile email exists.
    }

    final inviteToken = PendingAuthLink.takeRoundInviteToken();
    if (inviteToken != null && inviteToken.isNotEmpty) {
      try {
        await HistoryRepository.acceptRoundInviteForCurrentUser(inviteToken);
      } catch (_) {
        // Non-fatal: invite claim can be retried from a later session.
      }
    }
  }
}
