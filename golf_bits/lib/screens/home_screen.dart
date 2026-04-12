import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_root.dart';
import '../config/supabase_env.dart';
import '../theme/app_theme.dart';
import '../widgets/outlined_surface_card.dart';
import 'component_gallery_screen.dart';
import 'history_screen.dart';
import 'hole_scoring_screen.dart';
import 'round_setup_screen.dart';

/// Main shell: home dashboard + bottom nav (History, People, Profile).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  void _openHistoryTab() => setState(() => _navIndex = 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _navIndex,
        children: [
          _HomeDashboard(onOpenHistoryTab: _openHistoryTab),
          const HistoryScreen(),
          const _PeopleTab(),
          const _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
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
  const _HomeDashboard({required this.onOpenHistoryTab});

  final VoidCallback onOpenHistoryTab;

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  /// Demo: switch between idle and in-progress home (replace with session store later).
  bool _roundInProgress = false;
  bool _showSyncBanner = true;

  static const _activeCourse = 'Royal Melbourne';
  static const _activeCourseDetail = 'WEST COURSE · CHAMPIONSHIP TEES';
  static const _activeHole = 7;
  static const _activePlayers = ['Alex', 'Jamie', 'Chris', 'Sam'];

  static const _prevCourse = 'Royal Melbourne';
  static const _prevDate = 'Oct 12, 2023';
  static const _prevPlayers = ['Alex', 'Jamie', 'Chris', 'Sam'];
  static const _prevWinner = 'Alex';
  static const _prevWinnerBits = 12;

  String _initials(String name) {
    final t = name.trim();
    if (t.length >= 2) return t.substring(0, 2).toUpperCase();
    return t.isEmpty ? '?' : t.toUpperCase();
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
            onSelected: (v) {
              switch (v) {
                case 'gallery':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ComponentGalleryScreen()),
                  );
                case 'preview':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const HoleScoringScreen()),
                  );
                case 'toggle':
                  setState(() => _roundInProgress = !_roundInProgress);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'gallery', child: Text('Style guide & components')),
              const PopupMenuItem(value: 'preview', child: Text('Preview in-round UI')),
              PopupMenuItem(
                value: 'toggle',
                child: Text(_roundInProgress ? 'Demo: show idle home' : 'Demo: show active round'),
              ),
            ],
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: AppTheme.screenPadding,
        children: [
          if (_roundInProgress) ..._buildActiveRound(context) else ..._buildIdle(context),
          if (_showSyncBanner) ...[
            SizedBox(height: AppTheme.space4),
            _SyncBanner(onDismiss: () => setState(() => _showSyncBanner = false)),
          ],
          SizedBox(height: MediaQuery.paddingOf(context).bottom + AppTheme.space4),
        ],
      ),
    );
  }

  List<Widget> _buildIdle(BuildContext context) {
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
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const RoundSetupScreen()),
                );
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
      OutlinedSurfaceCard(
        borderColor: scheme.outlineVariant,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_prevCourse, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(
              _prevDate,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            SizedBox(height: AppTheme.space4),
            Wrap(
              spacing: AppTheme.space2,
              runSpacing: AppTheme.space2,
              children: _prevPlayers
                  .map(
                    (p) => Chip(
                      avatar: Icon(Icons.person_outline, size: AppTheme.iconDense, color: scheme.onSurfaceVariant),
                      label: Text(_initials(p)),
                      labelStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                      side: BorderSide(color: scheme.outlineVariant),
                      backgroundColor: scheme.surfaceContainerHigh,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
            SizedBox(height: AppTheme.space4),
            Align(
              alignment: Alignment.centerRight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3, vertical: AppTheme.space2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_outlined, size: AppTheme.iconDense, color: scheme.secondary),
                      SizedBox(width: AppTheme.space2),
                      Text(
                        '$_prevWinner (+$_prevWinnerBits)',
                        style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildActiveRound(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

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
              _activeCourse,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            SizedBox(height: AppTheme.space1),
            Text(
              _activeCourseDetail,
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
                    'CURRENT HOLE $_activeHole',
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
              children: _activePlayers
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
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const HoleScoringScreen()),
                );
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
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RoundSetupScreen()),
            );
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
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: Center(
        child: Text(
          'Friend groups and invites — coming soon',
          style: text.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
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
