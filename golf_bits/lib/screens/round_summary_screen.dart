import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../data/history_repository.dart';
import '../models/round_result.dart';
import '../theme/app_theme.dart';
import '../widgets/outlined_surface_card.dart';
import 'player_breakdown_screen.dart';

/// End of round: winner spotlight, standings, retired list, actions.
class RoundSummaryScreen extends StatefulWidget {
  const RoundSummaryScreen({super.key, this.result});

  /// When null, shows [RoundResult.previewDemo] (resume / preview entry points).
  final RoundResult? result;

  @override
  State<RoundSummaryScreen> createState() => _RoundSummaryScreenState();
}

class _RoundSummaryScreenState extends State<RoundSummaryScreen> {
  bool _saving = false;

  RoundResult get _r => widget.result ?? RoundResult.previewDemo();

  Future<void> _backToHome() async {
    final live = widget.result;
    if (live != null &&
        SupabaseEnv.isConfigured &&
        Supabase.instance.client.auth.currentSession != null) {
      setState(() => _saving = true);
      try {
        final row = live.toInsertRow();
        final roundId = live.roundId;
        if (roundId != null && roundId.isNotEmpty) {
          await HistoryRepository.completeRound(roundId: roundId, row: row);
        }
        final savedRoundId = roundId ?? await HistoryRepository.saveCompletedRound(row);
        var bitLine = '';
        try {
          if (roundId == null || roundId.isEmpty) {
            await HistoryRepository.saveBitEventsForRound(savedRoundId, live.bitEvents);
          }
        } catch (e) {
          bitLine = ' Bit timeline not stored: $e';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Round saved to your history.$bitLine')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save round: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final r = _r;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: AppTheme.screenPadding,
          children: [
            SizedBox(height: AppTheme.space4),
            Icon(Icons.emoji_events_outlined, size: AppTheme.iconLarge, color: scheme.secondary),
            SizedBox(height: AppTheme.space3),
            Text(
              r.winnerName,
              textAlign: TextAlign.center,
              style: text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
              ),
            ),
            Text(
              '+${r.winnerBits} BITS',
              textAlign: TextAlign.center,
              style: text.displaySmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: AppTheme.space3),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
                  border: Border.all(color: scheme.primary.withValues(alpha: AppTheme.opacityPrimaryBorder)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space4,
                    vertical: AppTheme.space2,
                  ),
                  child: Text(
                    r.completed ? 'ROUND COMPLETE' : 'ROUND IN PROGRESS',
                    style: text.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                      letterSpacing: AppTheme.letterStepCaps,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: AppTheme.space8),
            Text(
              'FINAL STANDINGS',
              style: text.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: AppTheme.letterStepCaps,
              ),
            ),
            SizedBox(height: AppTheme.space3),
            ...r.standings.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PlayerBreakdownScreen(playerName: s.name),
                        ),
                      );
                    },
                    child: OutlinedSurfaceCard(
                      borderColor: scheme.outlineVariant,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space4,
                        vertical: AppTheme.space3,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: AppTheme.space3,
                            backgroundColor: scheme.surfaceContainerHigh,
                            child: Text(
                              '${s.rank}',
                              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          SizedBox(width: AppTheme.space3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                Text(
                                  s.subtitle,
                                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            s.bits >= 0 ? '+${s.bits}' : '${s.bits}',
                            style: text.titleLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
            if (r.leftEarly.isNotEmpty) ...[
              SizedBox(height: AppTheme.space6),
              Text(
                'RETIRED EARLY',
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: AppTheme.letterStepCaps,
                ),
              ),
              SizedBox(height: AppTheme.space3),
              ...r.leftEarly.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space2),
                  child: OutlinedSurfaceCard(
                    borderColor: scheme.outlineVariant,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space4,
                      vertical: AppTheme.space3,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                              Text(
                                'Left hole ${e.leftHole}',
                                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          e.bitsLabel,
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: AppTheme.space8),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share sheet — coming soon')),
                );
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share Results'),
            ),
            SizedBox(height: AppTheme.space3),
            OutlinedButton(
              onPressed: _saving ? null : _backToHome,
              child: _saving
                  ? SizedBox(
                      height: AppTheme.iconInline,
                      width: AppTheme.iconInline,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    )
                  : const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
