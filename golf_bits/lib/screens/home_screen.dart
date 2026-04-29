import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_root.dart';
import '../config/supabase_env.dart';
import '../data/history_repository.dart';
import '../main.dart';
import '../data/schema_compatibility_service.dart';
import '../models/history_round.dart';
import '../models/round_session_args.dart';
import '../theme/app_theme.dart';
import '../widgets/history_round_card.dart';
import '../widgets/outlined_surface_card.dart';
import 'component_gallery_screen.dart';
import 'friends_screen.dart';
import 'history_detail_screen.dart';
import 'history_screen.dart';
import 'hole_scoring_screen.dart';
import 'profile_event_defaults_screen.dart';
import 'round_setup_screen.dart';

/// Main shell: home dashboard + bottom nav (History, People, Profile).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();
  final GlobalKey<_HomeDashboardState> _homeDashboardKey = GlobalKey<_HomeDashboardState>();

  void _openHistoryTab() {
    setState(() => _navIndex = 1);
    _historyKey.currentState?.reloadFromParent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _navIndex,
        children: [
          _HomeDashboard(key: _homeDashboardKey, onOpenHistoryTab: _openHistoryTab),
          HistoryScreen(key: _historyKey),
          const _PeopleTab(),
          const _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) {
          final prev = _navIndex;
          setState(() => _navIndex = i);
          if (i == 1 && prev != 1) {
            _historyKey.currentState?.reloadFromParent();
          }
          if (i == 0 && prev != 0) {
            _homeDashboardKey.currentState?.reloadFromParent();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'People',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard({super.key, required this.onOpenHistoryTab});

  final VoidCallback onOpenHistoryTab;

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> with RouteAware {
  /// Called when the user switches back to the Home tab so rounds stay fresh.
  void reloadFromParent() => unawaited(_loadDashboard());

  bool _loading = true;
  String? _loadError;
  HistoryRound? _activeRound;
  HistoryRound? _previousRound;
  bool _showSyncBanner = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDashboard());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appRouteObserver.unsubscribe(this);
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    unawaited(_loadDashboard());
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      if (!SupabaseEnv.isConfigured || Supabase.instance.client.auth.currentUser == null) {
        if (mounted) {
          setState(() {
            _activeRound = null;
            _previousRound = null;
            _loading = false;
          });
        }
        return;
      }
      final snapshot = await HistoryRepository.fetchHomeDashboardRounds();
      if (!mounted) return;
      setState(() {
        _activeRound = snapshot.active;
        _previousRound = snapshot.previous;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _activeRound = null;
        _previousRound = null;
        _loading = false;
      });
    }
  }

  static bool _isGuestUser() {
    if (!SupabaseEnv.isConfigured) return false;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    final provider = user.appMetadata['provider'];
    return provider == 'anonymous';
  }

  Future<void> _signOut(BuildContext context) async {
    if (SupabaseEnv.isConfigured && Supabase.instance.client.auth.currentSession != null) {
      await Supabase.instance.client.auth.signOut();
      return;
    }
    AuthRoot.maybeOf(context)?.exitApp();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag, size: AppTheme.iconInline, color: scheme.primary),
            SizedBox(width: AppTheme.space2),
            Text(
              'Golf Bits',
              style: text.titleLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'gallery':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ComponentGalleryScreen()),
                  );
                  return;
                case 'preview':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const HoleScoringScreen()),
                  );
                  return;
                case 'logout':
                  try {
                    await _signOut(context);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not log out: $e')),
                    );
                  }
                  return;
                default:
                  return;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'gallery', child: Text('Style guide & components')),
              const PopupMenuItem(value: 'preview', child: Text('Preview in-round UI')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                padding: AppTheme.screenPadding,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_loadError != null) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.space4),
                        child: Text(
                          'Could not load dashboard: $_loadError',
                          style: text.bodySmall?.copyWith(color: scheme.onErrorContainer),
                        ),
                      ),
                    ),
                    SizedBox(height: AppTheme.space4),
                  ],
                  if (_activeRound != null) ..._buildActiveRound(context, _activeRound!) else ..._buildNoActiveRoundCard(context),
                  ..._buildPreviousSessionSection(context),
                  if (_isGuestUser() && _showSyncBanner) ...[
                    SizedBox(height: AppTheme.space4),
                    _SyncBanner(onDismiss: () => setState(() => _showSyncBanner = false)),
                  ],
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + AppTheme.space4),
                ],
              ),
            ),
    );
  }

  /// Shown when there is no in-progress row in Supabase (`completed = false`).
  List<Widget> _buildNoActiveRoundCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return [
      OutlinedSurfaceCard(
        borderColor: scheme.outlineVariant,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'READY TO PLAY?',
              style: text.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: AppTheme.letterStepCaps,
              ),
            ),
            SizedBox(height: AppTheme.space3),
            Text(
              'No active round.',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: AppTheme.space6),
            FilledButton(
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const RoundSetupScreen()),
                );
                if (mounted) await _loadDashboard();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: AppTheme.iconInline),
                  SizedBox(width: AppTheme.space25),
                  const Text('Start New Round'),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildPreviousSessionSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final prev = _previousRound;

    return [
      SizedBox(height: AppTheme.space8),
      Row(
        children: [
          Text(
            'PREVIOUS SESSION',
            style: text.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: AppTheme.letterStepCaps,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: widget.onOpenHistoryTab,
            child: Text(
              'View All History →',
              style: text.labelLarge?.copyWith(
                color: scheme.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: AppTheme.space3),
      if (prev == null)
        OutlinedSurfaceCard(
          borderColor: scheme.outlineVariant,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'No completed rounds yet',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: AppTheme.space2),
              Text(
                'Finish a round and it will show up here, or open History for the full list.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        )
      else
        HistoryRoundCard(
          round: prev,
          onTap: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => HistoryDetailScreen(round: prev)),
            );
          },
        ),
    ];
  }

  List<Widget> _buildActiveRound(BuildContext context, HistoryRound round) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final detailLine = '${round.holeCount} holes · ${round.whenRelative}';

    return [
      Row(
        children: [
          Text(
            'ROUND IN PROGRESS',
            style: text.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: AppTheme.letterStepCaps,
            ),
          ),
          SizedBox(width: AppTheme.space2),
          Container(
            width: AppTheme.space2,
            height: AppTheme.space2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary,
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: AppTheme.opacityHeroGlow),
                  blurRadius: AppTheme.elevationBlurSm,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
      SizedBox(height: AppTheme.space4),
      OutlinedSurfaceCard(
        borderColor: scheme.primary.withValues(alpha: AppTheme.opacityPrimaryBorder),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              round.courseName,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            SizedBox(height: AppTheme.space1),
            Text(
              detailLine,
              style: text.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: AppTheme.letterStepCaps,
              ),
            ),
            SizedBox(height: AppTheme.space4),
            Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
                  border: Border.all(color: scheme.primary.withValues(alpha: AppTheme.opacityPrimaryBorder)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3, vertical: AppTheme.space2),
                  child: Text(
                    'IN PROGRESS',
                    style: text.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                      letterSpacing: AppTheme.letterBadge,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: AppTheme.space4),
            Wrap(
              spacing: AppTheme.space2,
              runSpacing: AppTheme.space2,
              children: round.players
                  .map(
                    (p) => Chip(
                      avatar: Icon(Icons.person_outline, size: AppTheme.iconDense, color: scheme.onSurfaceVariant),
                      label: Text(p),
                      side: BorderSide(color: scheme.outlineVariant),
                      backgroundColor: scheme.surfaceContainerHigh,
                    ),
                  )
                  .toList(),
            ),
            SizedBox(height: AppTheme.space6),
            FilledButton(
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => HoleScoringScreen(session: RoundSessionArgs.fromHistoryRound(round)),
                  ),
                );
                if (mounted) await _loadDashboard();
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('RESUME ROUND'),
                  SizedBox(width: AppTheme.space2),
                  Icon(Icons.arrow_forward, size: AppTheme.iconArrow),
                ],
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: AppTheme.space4),
      Center(
        child: TextButton(
          onPressed: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const RoundSetupScreen()),
            );
            if (mounted) await _loadDashboard();
          },
          child: Text(
            '+ START NEW ROUND',
            style: text.labelLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: AppTheme.letterStepCaps,
            ),
          ),
        ),
      ),
    ];
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.onDismiss});

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
          children: [
            Icon(Icons.sync, size: AppTheme.iconDense, color: scheme.onSurfaceVariant),
            SizedBox(width: AppTheme.space3),
            Expanded(
              child: Text(
                'Create an account to sync history across devices.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
              ),
            ),
            IconButton(
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

class _PeopleTab extends StatelessWidget {
  const _PeopleTab();

  @override
  Widget build(BuildContext context) {
    return const FriendsScreen();
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  static bool _isAnonymousUser(User? user) {
    if (user == null) return false;
    final provider = user.appMetadata['provider'];
    return provider == 'anonymous';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final session = SupabaseEnv.isConfigured ? Supabase.instance.client.auth.currentSession : null;
    final user = session?.user;
    final anon = user != null && _isAnonymousUser(user);
    final email = user?.email;
    final String title;
    if (!SupabaseEnv.isConfigured) {
      title = 'Playing on this device';
    } else if (anon) {
      title = 'Guest';
    } else if (email != null && email.isNotEmpty) {
      title = email;
    } else {
      title = 'Signed in';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: AppTheme.screenPadding,
        children: [
          OutlinedSurfaceCard(
            borderColor: scheme.outlineVariant,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Account', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: AppTheme.space3),
                Text(
                  title,
                  style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (anon) ...[
                  SizedBox(height: AppTheme.space2),
                  Text(
                    'Create an account any time to sync rounds across devices.',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: AppTheme.space6),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const ProfileEventDefaultsScreen()),
              );
            },
            icon: const Icon(Icons.tune),
            label: const Text('Default Round Events'),
          ),
          SizedBox(height: AppTheme.space3),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await SchemaCompatibilityService.checkRoundSyncSchema(forceRefresh: true);
              if (!context.mounted) return;
              await showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(result.ok ? 'Sync diagnostics: OK' : 'Sync diagnostics: issues found'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (result.errors.isEmpty)
                          const Text('No required schema issues detected.')
                        else ...[
                          const Text('Errors:'),
                          const SizedBox(height: AppTheme.space2),
                          Text(result.errors.join('\n')),
                        ],
                        if (result.warnings.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.space4),
                          const Text('Warnings:'),
                          const SizedBox(height: AppTheme.space2),
                          Text(result.warnings.join('\n')),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('Run Sync Diagnostics'),
          ),
          SizedBox(height: AppTheme.space3),
          FilledButton.tonal(
            onPressed: () async {
              if (SupabaseEnv.isConfigured && Supabase.instance.client.auth.currentSession != null) {
                await Supabase.instance.client.auth.signOut();
              } else {
                AuthRoot.maybeOf(context)?.exitApp();
              }
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
