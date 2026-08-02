import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_root.dart';
import 'auth/pending_auth_link.dart';
import 'config/supabase_env.dart';
import 'data/client_error_reporter.dart';
import 'data/history_repository.dart';
import 'data/schema_compatibility_service.dart';
import 'data/sync_status_notifier.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'theme/theme_preferences.dart';

final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      ClientErrorReporter.report(
        message: details.exceptionAsString(),
        stack: details.stack?.toString(),
        context: {'source': 'FlutterError.onError'},
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      ClientErrorReporter.report(
        message: error.toString(),
        stack: stack.toString(),
        context: {'source': 'PlatformDispatcher.onError'},
      ),
    );
    return true;
  };

  if (SupabaseEnv.isConfigured) {
    await _capturePendingAuthLink();
    await Supabase.initialize(
      url: SupabaseEnv.url,
      publishableKey: SupabaseEnv.anonKey,
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: true,
      ),
    );
    try {
      final compatibility = await SchemaCompatibilityService.checkRoundSyncSchema();
      HistoryRepository.configureRoundColumns(compatibility.detectedColumns['rounds']);
    } catch (_) {
      // Schema probe is best-effort; write fallbacks remain.
    }
  }

  final initialThemeMode = await ThemePreferences.loadInitialMode();
  runApp(GolfBitsApp(initialThemeMode: initialThemeMode));
}

/// Snapshot recovery / signup / invite params before Supabase may strip the URI.
Future<void> _capturePendingAuthLink() async {
  if (kIsWeb) {
    PendingAuthLink.captureFromUriBeforeSupabaseInit(Uri.base);
    return;
  }
  try {
    final initial = await AppLinks().getInitialLink();
    if (initial != null) {
      PendingAuthLink.captureFromUriBeforeSupabaseInit(initial);
    }
  } catch (_) {
    // Best-effort; AuthChangeEvent.passwordRecovery still covers reset links.
  }
}

/// Root app: Material 3, Bits Dots Junk brand, dark ("on course") + light
/// ("in the clubhouse") themes. Defaults to dark; light only when chosen in Profile.
class GolfBitsApp extends StatefulWidget {
  const GolfBitsApp({super.key, required this.initialThemeMode});

  final ThemeMode initialThemeMode;

  @override
  State<GolfBitsApp> createState() => _GolfBitsAppState();
}

class _GolfBitsAppState extends State<GolfBitsApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
  }

  void _setThemeMode(ThemeMode mode) {
    final resolved = mode == ThemeMode.light ? ThemeMode.light : ThemeMode.dark;
    if (resolved == _themeMode) return;
    setState(() => _themeMode = resolved);
    ThemePreferences.persistUserChoice(resolved);
  }

  @override
  Widget build(BuildContext context) {
    return ThemeController(
      mode: _themeMode,
      setMode: _setThemeMode,
      child: ListenableBuilder(
        listenable: SyncStatusNotifier.instance,
        builder: (context, _) {
          final syncFailing = SyncStatusNotifier.instance.syncFailing;
          final syncMessage = SyncStatusNotifier.instance.message;
          return MaterialApp(
            title: 'Bits Dots Junk',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _themeMode,
            navigatorObservers: [appRouteObserver],
            home: const AuthRoot(),
            builder: (context, child) {
              if (!syncFailing) return child ?? const SizedBox.shrink();
              final scheme = Theme.of(context).colorScheme;
              return Column(
                children: [
                  Material(
                    color: scheme.errorContainer,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space4,
                          vertical: AppTheme.space2,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_off, size: AppTheme.iconInline, color: scheme.onErrorContainer),
                            const SizedBox(width: AppTheme.space2),
                            Expanded(
                              child: Text(
                                syncMessage ?? 'Cloud sync is failing. Your scores are saved on this device.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onErrorContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: child ?? const SizedBox.shrink()),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
