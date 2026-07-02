import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_build_info.dart';
import '../config/supabase_env.dart';

/// Reports client errors to Supabase `client_errors` (best-effort).
abstract final class ClientErrorReporter {
  static Future<void> report({
    required String message,
    String? stack,
    Map<String, dynamic>? context,
  }) async {
    if (!SupabaseEnv.isConfigured) {
      debugPrint('ClientError: $message');
      if (stack != null) debugPrint(stack);
      return;
    }
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('client_errors').insert({
        'user_id': userId,
        'message': message.length > 4000 ? message.substring(0, 4000) : message,
        if (stack != null) 'stack': stack.length > 12000 ? stack.substring(0, 12000) : stack,
        if (context != null && context.isNotEmpty) 'context': context,
        'app_version': AppBuildInfo.displayLabel,
        'url': Uri.base.toString(),
      });
    } catch (e) {
      debugPrint('ClientErrorReporter failed: $e');
      debugPrint('Original: $message');
    }
  }

  static Future<void> reportFeedback(String feedback) async {
    await report(
      message: 'user_feedback',
      context: {'feedback': feedback.trim()},
    );
  }
}
