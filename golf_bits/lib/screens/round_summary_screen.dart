import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../data/history_repository.dart';
import '../models/round_result.dart';
import '../models/stroke_tracking.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/outlined_surface_card.dart';
import '../widgets/tally_marks.dart';
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
    final loggedInUser = Supabase.instance.client.auth.currentUser;
    var mayNavigateHome =
        live == null || !SupabaseEnv.isConfigured || loggedInUser == null;

    if (!mayNavigateHome) {
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
        mayNavigateHome = true;
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
    if (mounted && mayNavigateHome) {
      if (live != null && SupabaseEnv.isConfigured && loggedInUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Round not saved — guest cloud sync is not active. Try guest sync from History, or create an account.',
            ),
          ),
        );
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final r = _r;
    final liveResult = widget.result;
    final unsavedGuestRound = liveResult != null &&
        SupabaseEnv.isConfigured &&
        Supabase.instance.client.auth.currentSession == null;

    return Scaffold(
      appBar: const BrandAppBar(),
      body: ListView(
        padding: AppTheme.screenPadding,
        children: [
          if (unsavedGuestRound) ...[
            OutlinedSurfaceCard(
              borderColor: scheme.outlineVariant,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_off_outlined, color: scheme.onSurfaceVariant, size: AppTheme.iconInline),
                  SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: Text(
                      'Guest cloud sync is off, so this round will not appear in History. '
                      'Try guest sync from the History tab, or create an account.',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppTheme.space4),
          ],
          Text(
              '${r.courseShortTitle} · ${r.holeCount} HOLES',
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: AppTheme.letterStepCaps,
              ),
            ),
            SizedBox(height: AppTheme.space2),
            Text(
              r.completed ? 'Round complete' : 'Round in progress',
              textAlign: TextAlign.center,
              style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: AppTheme.space6),
            _WinnerHero(result: r),
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
            ...r.standings.map((s) {
              final holeOrder = List<int>.generate(r.holeCount, (i) => i + 1);
              final grossLine = grossLabelForStanding(
                mode: r.strokeTrackingMode,
                grossByPlayer: r.grossByPlayer,
                holePars: r.holePars,
                holeOrder: holeOrder,
                strokeByHole: r.strokeByHole,
                participantKey: s.participantKey,
              );
              final scoreColor = s.bits > 0
                  ? AppTheme.bits(context)
                  : s.bits < 0
                      ? AppTheme.junk(context)
                      : scheme.onSurfaceVariant;
              final bitsLabel = s.bits >= 0 ? '+${s.bits}' : '${s.bits}';
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space2),
                child: Semantics(
                  button: true,
                  label: '${s.name}, rank ${s.rank}, $bitsLabel bits. Tap for breakdown.',
                  child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PlayerBreakdownScreen(
                          roundId: r.roundId ?? '',
                          playerName: s.name,
                          participantKey: s.participantKey,
                          courseShortTitle: r.courseShortTitle,
                          strokeByHole: r.strokeByHole,
                          holePars: r.holePars,
                          grossByPlayer: r.grossByPlayer,
                        ),
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
                        SizedBox(
                          width: AppTheme.space5,
                          child: Text(
                            '${s.rank}',
                            textAlign: TextAlign.center,
                            style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
                          ),
                        ),
                        SizedBox(width: AppTheme.space2),
                        _SquareAvatar(name: s.name),
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
                              if (grossLine != null)
                                Text(
                                  grossLine,
                                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppTheme.space2),
                        SizedBox(
                          width: 52,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: TallyMarks(
                              count: s.bits,
                              height: 16,
                              variant: s.bits < 0 ? TallyVariant.penalty : TallyVariant.positive,
                            ),
                          ),
                        ),
                        SizedBox(width: AppTheme.space3),
                        Text(
                          s.bits >= 0 ? '+${s.bits}' : '${s.bits}',
                          style: AppTheme.score(context, size: 24, color: scoreColor),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              );
            }),
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
            Semantics(
              button: true,
              label: 'Share results',
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share sheet — coming soon')),
                  );
                },
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share Results'),
              ),
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
    );
  }
}

/// Winner spotlight: Fairway-emphasis card, rounded-square avatar, big Bricolage
/// score + a hero tally.
class _WinnerHero extends StatelessWidget {
  const _WinnerHero({required this.result});

  final RoundResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: 'Winner, ${result.winnerName}, plus ${result.winnerBits} bits',
      child: OutlinedSurfaceCard(
      borderColor: scheme.primary,
      child: Column(
        children: [
          Text('🏆  WINNER', style: AppTheme.monoLabel(context, color: AppTheme.sand(context))),
          SizedBox(height: AppTheme.space4),
          _SquareAvatar(name: result.winnerName, size: AppTheme.iconHero),
          SizedBox(height: AppTheme.space3),
          Text(
            result.winnerName,
            textAlign: TextAlign.center,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: AppTheme.space2),
          Text('+${result.winnerBits}', style: AppTheme.score(context, size: 44, color: AppTheme.bits(context))),
          SizedBox(height: AppTheme.space2),
          TallyMarks(count: result.winnerBits, height: 26),
          SizedBox(height: AppTheme.space1),
          Text('BITS', style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant)),
        ],
      ),
    ),
    );
  }
}

/// Rounded-square initial avatar (Fairway fill by default).
class _SquareAvatar extends StatelessWidget {
  const _SquareAvatar({required this.name, this.size = 36});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.avatarRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
