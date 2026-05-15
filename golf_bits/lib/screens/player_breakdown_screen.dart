import 'package:flutter/material.dart';

import '../config/supabase_env.dart';
import '../data/history_repository.dart';
import '../models/stroke_tracking.dart';
import '../theme/app_theme.dart';
import '../widgets/outlined_surface_card.dart';

class _TimelineEvent {
  const _TimelineEvent({
    required this.label,
    required this.bits,
    required this.icon,
    this.negative = false,
  });

  final String label;
  final int bits;
  final IconData icon;
  final bool negative;
}

class _TimelineHole {
  const _TimelineHole({
    required this.hole,
    required this.par,
    required this.gross,
    required this.events,
  });

  final int hole;
  final int? par;
  final int? gross;
  final List<_TimelineEvent> events;
}

IconData _iconForKey(String? key) {
  return switch (key) {
    'sports_golf' => Icons.sports_golf,
    'trending_up' => Icons.trending_up,
    'flag_outlined' => Icons.flag_outlined,
    'radio_button_checked_outlined' => Icons.radio_button_checked_outlined,
    'remove_circle_outline' => Icons.remove_circle_outline,
    'waves_outlined' => Icons.waves_outlined,
    _ => Icons.star_outline,
  };
}

bool _shouldLoadFromSupabase(String roundId) {
  if (!SupabaseEnv.isConfigured || roundId.isEmpty) return false;
  return RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(roundId);
}

/// Per-player round timeline (strokes + Supabase `round_bit_events` when saved).
class PlayerBreakdownScreen extends StatefulWidget {
  const PlayerBreakdownScreen({
    super.key,
    this.roundId = '',
    required this.playerName,
    this.participantKey,
    this.courseShortTitle,
    this.dateHeader,
    this.strokeByHole = const {},
    this.holePars = const {},
    this.grossByPlayer = const {},
  });

  final String roundId;
  final String playerName;
  final String? participantKey;
  final String? courseShortTitle;
  final String? dateHeader;
  final Map<String, Map<int, int>> strokeByHole;
  final Map<String, int> holePars;
  final Map<String, int> grossByPlayer;

  @override
  State<PlayerBreakdownScreen> createState() => _PlayerBreakdownScreenState();
}

class _PlayerBreakdownScreenState extends State<PlayerBreakdownScreen> {
  late final Future<List<_TimelineHole>> _holesFuture;

  @override
  void initState() {
    super.initState();
    _holesFuture = _loadHoles();
  }

  Map<int, int>? get _playerStrokes {
    final key = widget.participantKey;
    if (key != null && key.isNotEmpty) {
      return widget.strokeByHole[key];
    }
    return null;
  }

  Future<List<_TimelineHole>> _loadHoles() async {
    final strokes = _playerStrokes ?? {};
    final bitRows = _shouldLoadFromSupabase(widget.roundId)
        ? await HistoryRepository.fetchBitEventsForPlayer(
            roundId: widget.roundId,
            playerName: widget.playerName,
            participantKey: widget.participantKey,
          )
        : <Map<String, dynamic>>[];

    final byHole = <int, List<Map<String, dynamic>>>{};
    for (final r in bitRows) {
      final h = (r['hole'] as num).toInt();
      byHole.putIfAbsent(h, () => []).add(r);
    }

    final holeNums = <int>{...strokes.keys, ...byHole.keys}.toList()..sort();
    if (holeNums.isEmpty) return [];

    return holeNums.map((h) {
      final raw = byHole[h] ?? [];
      final events = raw.map((m) {
        final d = (m['delta'] as num).toInt();
        return _TimelineEvent(
          label: m['event_label'] as String,
          bits: d,
          icon: _iconForKey(m['icon_key'] as String?),
          negative: d < 0,
        );
      }).toList();
      final gross = strokes[h];
      final par = parForHole(widget.holePars, h);
      return _TimelineHole(hole: h, par: par, gross: gross, events: events);
    }).toList();
  }

  int _totalBits(List<_TimelineHole> holes) =>
      holes.expand((h) => h.events).fold<int>(0, (s, e) => s + e.bits);

  String? _grossFooterLabel() {
    final key = widget.participantKey;
    if (key == null || key.isEmpty) return null;
    final gross = widget.grossByPlayer[key];
    if (gross == null || gross <= 0) return null;
    final holes = widget.strokeByHole[key];
    if (holes == null || holes.isEmpty) return 'Score $gross';
    final order = holes.keys.toList()..sort();
    return 'Score ${formatGrossWithToPar(
      gross: gross,
      holePars: widget.holePars,
      holeOrder: order,
      playerHoles: holes,
    )}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final course = widget.courseShortTitle ?? 'Round';
    final date = widget.dateHeader ?? '';
    final grossFooter = _grossFooterLabel();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Player Breakdown'),
      ),
      body: FutureBuilder<List<_TimelineHole>>(
        future: _holesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final holes = snapshot.data ?? [];
          final total = _totalBits(holes);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: AppTheme.screenPadding,
                  children: [
                    Text(
                      'ROUND PERFORMANCE',
                      style: text.labelSmall?.copyWith(
                        color: scheme.secondary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: AppTheme.letterStepCaps,
                      ),
                    ),
                    SizedBox(height: AppTheme.space2),
                    Text(
                      widget.playerName,
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      course,
                      style: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    SizedBox(height: AppTheme.space2),
                    if (grossFooter != null)
                      Text(
                        grossFooter,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    Text(
                      '${total >= 0 ? '+' : ''}$total BITS',
                      style: text.headlineSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: AppTheme.space6),
                    if (holes.isEmpty)
                      Text(
                        _shouldLoadFromSupabase(widget.roundId)
                            ? 'No strokes or bit events recorded for this player in this round.'
                            : 'Open this screen from a saved round in History to see hole-by-hole detail.',
                        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      )
                    else
                      ...holes.expand((h) => [
                            _HoleTimelineBlock(hole: h, scheme: scheme, text: text),
                            SizedBox(height: AppTheme.space4),
                          ]),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  left: AppTheme.pageHorizontal,
                  right: AppTheme.pageHorizontal,
                  top: AppTheme.space3,
                  bottom: MediaQuery.paddingOf(context).bottom + AppTheme.space3,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  border: Border(top: BorderSide(color: scheme.outlineVariant)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'TOTAL BREAKDOWN',
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: AppTheme.letterStepCaps,
                      ),
                    ),
                    if (grossFooter != null)
                      Text(
                        grossFooter,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    Text(
                      '${total >= 0 ? '+' : ''}$total BITS',
                      style: text.headlineSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: AppTheme.space3),
                    FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Share breakdown — coming soon')),
                        );
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share Breakdown'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HoleTimelineBlock extends StatelessWidget {
  const _HoleTimelineBlock({
    required this.hole,
    required this.scheme,
    required this.text,
  });

  final _TimelineHole hole;
  final ColorScheme scheme;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final gross = hole.gross;
    final par = hole.par;
    final grossLabel = gross != null
        ? 'Score $gross (${scoreToParLabel(strokes: gross, par: par)})'
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: AppTheme.space8,
              height: AppTheme.space8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
                border: Border.all(color: scheme.primary.withValues(alpha: AppTheme.opacityPrimaryBorder)),
              ),
              child: Center(
                child: Text(
                  '${hole.hole}',
                  style: text.labelLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Text(
              par != null ? 'PAR $par' : 'PAR —',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        SizedBox(width: AppTheme.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (grossLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space2),
                  child: Text(
                    grossLabel,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              if (hole.events.isEmpty)
                Text(
                  'No bit events on this hole',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ...hole.events.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space2),
                  child: OutlinedSurfaceCard(
                    borderColor: e.negative ? scheme.error : scheme.outlineVariant,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space3,
                      vertical: AppTheme.space2,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          e.icon,
                          color: e.negative ? scheme.error : scheme.primary,
                          size: AppTheme.iconDense,
                        ),
                        SizedBox(width: AppTheme.space3),
                        Expanded(
                          child: Text(
                            e.label,
                            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${e.bits >= 0 ? '+' : ''}${e.bits}',
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: e.negative ? scheme.error : scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
