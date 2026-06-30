import 'package:flutter/material.dart';

import '../data/wolf_round_sync.dart';
import '../models/wolf_round_state.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/outlined_surface_card.dart';
import '../widgets/player_avatar.dart';
import '../widgets/tally_marks.dart';

/// Screen 06 — mid-round standings (Wolf / Bits toggle).
class RoundStandingsScreen extends StatefulWidget {
  const RoundStandingsScreen({super.key, required this.state});

  final WolfRoundState state;

  @override
  State<RoundStandingsScreen> createState() => _RoundStandingsScreenState();
}

class _RoundStandingsScreenState extends State<RoundStandingsScreen> {
  bool _showWolf = true;

  WolfRoundState get _state => widget.state;

  List<({String key, String name, int score})> _wolfRows() {
    final totals = WolfRoundSync.computeWolfTotals(_state.wolfHoleResults);
    final rows = [
      for (final p in _state.session.participants)
        (key: p.key, name: p.displayName, score: totals[p.key] ?? 0),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return rows;
  }

  List<({String key, String name, int score})> _bitsRows() {
    final rows = [
      for (final p in _state.session.participants)
        (key: p.key, name: p.displayName, score: _state.bitsByPlayer[p.key] ?? 0),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final showBoth = _state.session.hasWolf && _state.session.hasBits;
    final rows = _showWolf || !_state.session.hasBits ? _wolfRows() : _bitsRows();

    return Scaffold(
      appBar: const BrandAppBar(),
      body: ListView(
        padding: AppTheme.screenPadding,
        children: [
          Text(
            '${_state.session.courseShortTitle.toUpperCase()} · THRU ${_state.holeIndex}',
            style: AppTheme.monoLabel(context, color: AppTheme.bits(context)),
          ),
          Text('Standings', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          if (showBoth) ...[
            SizedBox(height: AppTheme.space3),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Wolf')),
                ButtonSegment(value: false, label: Text('Bits')),
              ],
              selected: {_showWolf},
              onSelectionChanged: (s) => setState(() => _showWolf = s.first),
            ),
          ],
          SizedBox(height: AppTheme.space4),
          Text(
            _showWolf ? 'WOLF POINTS · THE MATCH' : 'BITS LEDGER · SIDE GAME',
            style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
          ),
          SizedBox(height: AppTheme.space2),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space2),
              child: OutlinedSurfaceCard(
                borderColor: i == 0 ? AppTheme.sand(context).withValues(alpha: 0.45) : scheme.outlineVariant,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3, vertical: AppTheme.space2),
                child: Row(
                  children: [
                    Text('${i + 1}', style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant)),
                    SizedBox(width: AppTheme.space2),
                    PlayerAvatar(
                      displayName: rows[i].name,
                      colorIndex: _state.teeOrder.indexOf(rows[i].key).clamp(0, 3),
                      size: 34,
                    ),
                    SizedBox(width: AppTheme.space2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rows[i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (i == 0)
                            Text(
                              '★ LEADING',
                              style: AppTheme.monoLabel(context, color: AppTheme.sand(context)),
                            ),
                        ],
                      ),
                    ),
                    if (_showWolf)
                      TallyMarks(count: rows[i].score, height: 20)
                    else
                      Text(
                        rows[i].score >= 0 ? '+${rows[i].score}' : '${rows[i].score}',
                        style: AppTheme.score(
                          context,
                          size: 20,
                          color: rows[i].score >= 0 ? AppTheme.bits(context) : AppTheme.junk(context),
                        ),
                      ),
                    SizedBox(width: AppTheme.space2),
                    Text(
                      '${rows[i].score}',
                      style: AppTheme.score(context, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: AppTheme.space4),
          Text(
            _showWolf
                ? '\$${_state.gameConfig.wolfPointValue.toStringAsFixed(0)} / POINT · SETTLES AT THE END'
                : '\$${_state.gameConfig.bitsPointValue.toStringAsFixed(0)} / BIT · SETTLES AT THE END',
            textAlign: TextAlign.center,
            style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
