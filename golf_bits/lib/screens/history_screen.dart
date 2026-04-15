import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../data/history_repository.dart';
import '../models/history_round.dart';
import '../theme/app_theme.dart';
import '../widgets/history_round_card.dart';
import '../widgets/outlined_surface_card.dart';
import 'history_detail_screen.dart';
import 'round_setup_screen.dart';

/// Past rounds list + empty state (Supabase `rounds` when configured, else demo data).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  late Future<List<HistoryRound>> _future;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _future = _loadRounds();
  }

  /// Called when switching to the History tab or opening History from Home.
  void reloadFromParent() {
    setState(() {
      _future = _loadRounds();
    });
    unawaited(_future);
  }

  Future<List<HistoryRound>> _loadRounds() async {
    _loadError = null;
    if (!SupabaseEnv.isConfigured) {
      return List<HistoryRound>.from(HistoryRound.demoRounds);
    }
    if (Supabase.instance.client.auth.currentSession == null) {
      return [];
    }
    try {
      return await HistoryRepository.fetchMyRounds();
    } catch (e) {
      _loadError = e.toString();
      return [];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadRounds();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        automaticallyImplyLeading: false,
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () async {
              await _refresh();
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share history — coming soon')),
              );
            },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<HistoryRound>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rounds = snapshot.data ?? [];
          if (_loadError != null && rounds.isEmpty && SupabaseEnv.isConfigured) {
            return Center(
              child: Padding(
                padding: AppTheme.screenPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Could not load history',
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: AppTheme.space3),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    SizedBox(height: AppTheme.space6),
                    Text(
                      'If this is the first setup, run the SQL migration in `supabase/migrations/` '
                      'in the Supabase SQL editor, then refresh.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    SizedBox(height: AppTheme.space6),
                    FilledButton(onPressed: () => setState(() => _future = _loadRounds()), child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }
          if (rounds.isEmpty) {
            final signedOut = SupabaseEnv.isConfigured && Supabase.instance.client.auth.currentSession == null;
            if (signedOut) {
              return _HistoryNeedSignIn(
                onOpenProfile: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Use the Profile tab to sign in.')),
                  );
                },
              );
            }
            return _HistoryEmpty(onStartRound: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const RoundSetupScreen()),
              );
            });
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: AppTheme.screenPadding,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (!SupabaseEnv.isConfigured)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space4),
                    child: Text(
                      'Demo data (add Supabase secrets to load your rounds).',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                Row(
                  children: [
                    Text(
                      'RECENT ROUNDS',
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: AppTheme.letterStepCaps,
                      ),
                    ),
                    const Spacer(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
                        border: Border.all(color: scheme.primary.withValues(alpha: AppTheme.opacityPrimaryBorder)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3, vertical: AppTheme.space1),
                        child: Text(
                          '${rounds.length} total',
                          style: text.labelSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.space4),
                ...rounds.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.space3),
                      child: HistoryRoundCard(
                        round: r,
                        onTap: () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => HistoryDetailScreen(round: r),
                            ),
                          );
                          if (context.mounted) await _refresh();
                        },
                      ),
                    )),
                SizedBox(height: AppTheme.space8),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistoryNeedSignIn extends StatelessWidget {
  const _HistoryNeedSignIn({required this.onOpenProfile});

  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: AppTheme.screenPadding,
      child: Column(
        children: [
          const Spacer(flex: 2),
          Icon(Icons.lock_outline, size: AppTheme.iconLarge, color: scheme.onSurfaceVariant),
          SizedBox(height: AppTheme.space6),
          Text(
            'Sign in to see history',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: AppTheme.space2),
          Text(
            'Your finished rounds are saved to your account. Open Profile to sign in or create an account.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(flex: 3),
          OutlinedButton(
            onPressed: onOpenProfile,
            child: const Text('How to sign in'),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + AppTheme.space4),
        ],
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.onStartRound});

  final VoidCallback onStartRound;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: AppTheme.screenPadding,
      child: Column(
        children: [
          const Spacer(flex: 2),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space8),
              child: Icon(Icons.flag_outlined, size: AppTheme.iconLarge, color: scheme.primary),
            ),
          ),
          SizedBox(height: AppTheme.space6),
          Text(
            'No rounds yet',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: AppTheme.space2),
          Text(
            'Finish your first round and it’ll appear here',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(flex: 3),
          FilledButton(
            onPressed: onStartRound,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Start a Round'),
                SizedBox(width: AppTheme.space2),
                Icon(Icons.arrow_forward, size: AppTheme.iconArrow),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + AppTheme.space4),
        ],
      ),
    );
  }
}
