import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/guest_promotion.dart';
import '../auth/guest_user.dart';
import '../config/app_build_info.dart';
import '../config/supabase_env.dart';
import '../data/client_error_reporter.dart';
import '../auth/guest_session.dart';
import '../navigation/auth_navigation.dart';
import '../data/history_repository.dart';
import '../data/round_session_store.dart';
import '../data/user_preferences_repository.dart';
import '../data/wolf_round_sync.dart';
import '../main.dart';
import '../models/history_round.dart';
import '../models/round_session_args.dart';
import '../models/wolf_round_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/tally_marks.dart';
import '../widgets/guest_promotion_strip.dart';
import '../widgets/history_round_card.dart';
import '../widgets/outlined_surface_card.dart';
import 'friends_screen.dart';
import 'history_detail_screen.dart';
import 'history_screen.dart';
import 'hole_scoring_screen.dart';
import 'wolf_call_screen.dart';
import 'wolf_score_hole_screen.dart';
import 'change_password_screen.dart';
import 'guest_upgrade_screen.dart';
import 'log_in_screen.dart';
import 'profile_event_defaults_screen.dart';
import 'round_setup_screen.dart';
import 'sign_up_screen.dart';

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
  Map<String, dynamic>? _localDraft;

  Future<void> _dismissRound(HistoryRound round) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dismiss round?'),
        content: const Text('The round will be removed from your in-progress list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await HistoryRepository.deleteRound(round.id);
      if (mounted) await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not dismiss round: $e')),
      );
    }
  }

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
      final draft = await RoundSessionStore.loadDraft();
      if (!mounted) return;
      setState(() {
        _activeRound = snapshot.active;
        _previousRound = snapshot.previous;
        _localDraft = draft?.data;
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

  Future<void> _resumeLocalDraft() async {
    final draft = _localDraft;
    if (draft == null) return;
    final kind = (draft['kind'] as String?) ?? 'bits';
    if (kind == 'wolf') {
      final state = RoundSessionStore.wolfStateFromDraft(draft);
      if (state == null || !mounted) return;
      final screen = state.currentPhase == WolfInRoundPhase.score && state.pendingCall != null
          ? WolfScoreHoleScreen(state: state)
          : WolfCallScreen(state: state);
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
    } else {
      final sessionJson = draft['session'];
      if (sessionJson is! Map || !mounted) return;
      final session = RoundSessionStore.sessionFromJson(Map<String, dynamic>.from(sessionJson));
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => HoleScoringScreen(session: session)),
      );
    }
    if (mounted) await _loadDashboard();
  }

  Future<void> _discardLocalDraft() async {
    await RoundSessionStore.clearDraft();
    if (mounted) await _loadDashboard();
  }

  List<Widget> _buildLocalDraftCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sessionJson = _localDraft?['session'];
    final courseName = sessionJson is Map ? (sessionJson['courseName'] as String?) ?? 'Round' : 'Round';
    return [
      OutlinedSurfaceCard(
        borderColor: scheme.primary.withValues(alpha: AppTheme.opacityPrimaryBorder),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'LOCAL ROUND SAVED',
              style: text.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: AppTheme.letterStepCaps,
              ),
            ),
            SizedBox(height: AppTheme.space2),
            Text(
              'Resume $courseName on this device?',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: AppTheme.space4),
            FilledButton(onPressed: _resumeLocalDraft, child: const Text('Resume local round')),
            SizedBox(height: AppTheme.space2),
            TextButton(onPressed: _discardLocalDraft, child: const Text('Discard local save')),
          ],
        ),
      ),
      SizedBox(height: AppTheme.space4),
    ];
  }

  static bool _isGuestUser() {
    if (!SupabaseEnv.isConfigured) return false;
    return isSupabaseGuestUser(Supabase.instance.client.auth.currentUser);
  }

  Future<void> _signOut(BuildContext context) => signOutAndReturnToWelcome(context);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: BrandAppBar(
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Account menu',
            onSelected: (v) async {
              switch (v) {
                case 'logout':
                  final logoutMessenger = ScaffoldMessenger.of(context);
                  try {
                    await _signOut(context);
                  } catch (e) {
                    if (!mounted) return;
                    logoutMessenger.showSnackBar(
                      SnackBar(content: Text('Could not log out: $e')),
                    );
                  }
                  return;
                default:
                  return;
              }
            },
            itemBuilder: (ctx) => [
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
                  if (_localDraft != null) ..._buildLocalDraftCard(context),
                  if (_activeRound != null) ..._buildActiveRound(context, _activeRound!) else ..._buildNoActiveRoundCard(context),
                  ..._buildPreviousSessionSection(context),
                  if (_isGuestUser() && _showSyncBanner) ...[
                    SizedBox(height: AppTheme.space4),
                    GuestPromotionStrip(onDismiss: () => setState(() => _showSyncBanner = false)),
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
            SizedBox(height: AppTheme.space3),
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
    final scoreTiles = (round.standings.isNotEmpty
            ? round.standings.map((s) => (name: s.name, bits: s.bits))
            : round.players.map((p) => (name: p, bits: 0)))
        .take(4)
        .toList();

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < scoreTiles.length; i++) ...[
                  if (i > 0) SizedBox(width: AppTheme.space2),
                  Expanded(
                    child: _ScoreTile(name: scoreTiles[i].name, bits: scoreTiles[i].bits),
                  ),
                ],
              ],
            ),
            SizedBox(height: AppTheme.space6),
            FilledButton(
              onPressed: () async {
                final args = RoundSessionArgs.fromHistoryRound(round);
                Widget screen;
                if (round.hasWolf) {
                  var state = WolfRoundState.fromSession(args);
                  state = await WolfRoundSync.hydrateBitEvents(state);
                  if (!context.mounted) return;
                  screen = state.currentPhase == WolfInRoundPhase.score && state.pendingCall != null
                      ? WolfScoreHoleScreen(state: state)
                      : WolfCallScreen(state: state);
                } else {
                  screen = HoleScoringScreen(session: args);
                }
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => screen),
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
            SizedBox(height: AppTheme.space3),
            OutlinedButton.icon(
              onPressed: () => _dismissRound(round),
              icon: const Icon(Icons.delete_outline),
              label: const Text('DISMISS ROUND'),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(
                  color: scheme.error.withValues(alpha: AppTheme.opacityBorderEmphasis),
                ),
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

class _PeopleTab extends StatelessWidget {
  const _PeopleTab();

  @override
  Widget build(BuildContext context) {
    return const FriendsScreen();
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _marketingPrefsLoading = true;
  bool _marketingOptIn = false;

  static String _displayNameFor(User user) {
    final fullName = (user.userMetadata?['full_name'] as String?)?.trim();
    final fallbackName = user.email?.split('@').first.trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;
    if (fallbackName != null && fallbackName.isNotEmpty) return fallbackName;
    return 'Player';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadMarketingOptIn());
  }

  Future<void> _loadMarketingOptIn() async {
    if (!SupabaseEnv.isConfigured) {
      if (mounted) setState(() => _marketingPrefsLoading = false);
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || isSupabaseGuestUser(user)) {
      if (mounted) setState(() => _marketingPrefsLoading = false);
      return;
    }
    final v = await UserPreferencesRepository.fetchMarketingOptIn();
    if (!mounted) return;
    setState(() {
      _marketingOptIn = v;
      _marketingPrefsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final session = SupabaseEnv.isConfigured ? Supabase.instance.client.auth.currentSession : null;
    final user = session?.user;
    final anon = user != null && isSupabaseGuestUser(user);
    final email = user?.email;

    final showChangePassword = SupabaseEnv.isConfigured &&
        user != null &&
        !anon &&
        email != null &&
        email.isNotEmpty;
    final showMarketingEmails = SupabaseEnv.isConfigured && user != null && !anon;

    final children = <Widget>[];

    if (!SupabaseEnv.isConfigured) {
      children.add(
        OutlinedSurfaceCard(
          borderColor: scheme.outlineVariant,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Account', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              SizedBox(height: AppTheme.space3),
              Text(
                'Playing on this device',
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    } else if (user == null) {
      children.add(
        OutlinedSurfaceCard(
          borderColor: scheme.outlineVariant,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Account', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              SizedBox(height: AppTheme.space3),
              Text(
                'Guest sync not active',
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              SizedBox(height: AppTheme.space2),
              Text(
                'Rounds are not being saved to the cloud. Try guest sync below, or create an account.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              SizedBox(height: AppTheme.space6),
              FilledButton(
                onPressed: () async {
                  await retryGuestCloudSignIn(context);
                  if (mounted) setState(() {});
                },
                child: const Text('Try guest sync'),
              ),
              SizedBox(height: AppTheme.space3),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
                  );
                },
                child: const Text('Create free account'),
              ),
              SizedBox(height: AppTheme.space3),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const LogInScreen()),
                  );
                },
                child: const Text('Log in'),
              ),
            ],
          ),
        ),
      );
    } else if (anon) {
      children.add(
        OutlinedSurfaceCard(
          borderColor: scheme.primary.withValues(alpha: AppTheme.opacityPrimaryBorder),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.person_off_outlined, color: scheme.primary, size: AppTheme.iconInline + 4),
                  SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: Text(
                      GuestPromotionCopy.title,
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppTheme.space3),
              Text(
                GuestPromotionCopy.subtitle,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              SizedBox(height: AppTheme.space6),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const GuestUpgradeScreen()),
                  );
                },
                child: Text(GuestPromotionCopy.upgradeCta),
              ),
              SizedBox(height: AppTheme.space3),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const LogInScreen()),
                  );
                },
                child: const Text('Log in'),
              ),
              SizedBox(height: AppTheme.space3),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
                  );
                },
                child: Text(GuestPromotionCopy.createInsteadCta),
              ),
            ],
          ),
        ),
      );
    } else {
      children.add(
        OutlinedSurfaceCard(
          borderColor: scheme.outlineVariant,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Account', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              SizedBox(height: AppTheme.space3),
              Text(
                _displayNameFor(user),
                style: text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              if (email != null && email.isNotEmpty) ...[
                SizedBox(height: AppTheme.space1),
                Text(
                  email,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final themeController = ThemeController.maybeOf(context);
    if (themeController != null) {
      children.addAll([
        SizedBox(height: AppTheme.space6),
        Text(
          'APPEARANCE',
          style: text.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: AppTheme.letterStepCaps,
          ),
        ),
        SizedBox(height: AppTheme.space3),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ],
            selected: {themeController.mode},
            onSelectionChanged: (selection) => themeController.setMode(selection.first),
            showSelectedIcon: false,
          ),
        ),
      ]);
    }

    children.addAll([
      SizedBox(height: AppTheme.space6),
      Text(
        'ABOUT',
        style: text.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: AppTheme.letterStepCaps,
        ),
      ),
      SizedBox(height: AppTheme.space2),
      Text(
        AppBuildInfo.displayLabel,
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      SizedBox(height: AppTheme.space3),
      OutlinedButton.icon(
        onPressed: () async {
          final controller = TextEditingController();
          final sent = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Send feedback'),
              content: TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(hintText: 'What happened?'),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Send')),
              ],
            ),
          );
          if (sent != true || !context.mounted) return;
          final text = controller.text.trim();
          if (text.isEmpty) return;
          await ClientErrorReporter.reportFeedback(text);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thanks — feedback sent')),
          );
        },
        icon: const Icon(Icons.feedback_outlined),
        label: const Text('Send feedback'),
      ),
      SizedBox(height: AppTheme.space3),
      OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const ProfileEventDefaultsScreen()),
          );
        },
        icon: const Icon(Icons.casino),
        label: const Text('Default bets & events'),
      ),
      SizedBox(height: AppTheme.space3),
    ]);

    if (showChangePassword) {
      children.addAll([
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen()),
            );
          },
          icon: const Icon(Icons.lock_reset),
          label: const Text('Change password'),
        ),
        SizedBox(height: AppTheme.space2),
      ]);
    }

    if (showMarketingEmails) {
      children.add(
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Marketing emails', style: text.titleSmall),
          subtitle: Text(
            'Occasional updates, tips, and offers from Bits',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          value: _marketingOptIn,
          onChanged: _marketingPrefsLoading
              ? null
              : (next) async {
                  final marketingMessenger = ScaffoldMessenger.of(context);
                  final prev = _marketingOptIn;
                  setState(() => _marketingOptIn = next);
                  try {
                    await UserPreferencesRepository.saveMarketingOptIn(next);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _marketingOptIn = prev);
                    marketingMessenger.showSnackBar(
                      SnackBar(content: Text('Could not save preference: $e')),
                    );
                  }
                },
        ),
      );
    }

    children.addAll([
      SizedBox(height: AppTheme.space3),
      FilledButton.tonal(
        onPressed: () => signOutAndReturnToWelcome(context),
        child: const Text('Sign out'),
      ),
    ]);

    return Scaffold(
      appBar: const BrandAppBar(),
      body: ListView(
        padding: AppTheme.screenPadding,
        children: children,
      ),
    );
  }
}

/// Compact in-progress score tile: sign-coloured Bricolage total over the name
/// with a small tally, for the Home active-round card.
class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.name, required this.bits});

  final String name;
  final int bits;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = bits > 0
        ? AppTheme.bits(context)
        : bits < 0
            ? AppTheme.junk(context)
            : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppTheme.space3,
        horizontal: AppTheme.space2,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(bits >= 0 ? '+$bits' : '$bits', style: AppTheme.score(context, size: 22, color: color)),
          SizedBox(height: AppTheme.space1),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          SizedBox(height: AppTheme.spaceHalf),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: TallyMarks(
              count: bits,
              height: 12,
              variant: bits < 0 ? TallyVariant.penalty : TallyVariant.positive,
            ),
          ),
        ],
      ),
    );
  }
}
