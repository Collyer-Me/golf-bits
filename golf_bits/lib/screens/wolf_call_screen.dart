import 'dart:async';

import 'package:flutter/material.dart';

import '../data/wolf_round_sync.dart';
import '../models/round_session_args.dart';
import '../models/wolf_round_state.dart';
import '../models/wolf_scoring.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/hole_header.dart';
import '../widgets/outlined_surface_card.dart';
import '../widgets/player_avatar.dart';
import '../widgets/selectable_surface_card.dart';
import 'round_standings_screen.dart';
import 'wolf_score_hole_screen.dart';

/// Screen 03 — The Wolf's call (partner / lone / blind).
class WolfCallScreen extends StatefulWidget {
  const WolfCallScreen({super.key, required this.state});

  final WolfRoundState state;

  @override
  State<WolfCallScreen> createState() => _WolfCallScreenState();
}

class _WolfCallScreenState extends State<WolfCallScreen> {
  late WolfRoundState _state;
  WolfCall? _selectedCall;
  int _opponentsTeed = 0;

  @override
  void initState() {
    super.initState();
    _state = widget.state;
    _selectedCall = _state.pendingCall;
    _opponentsTeed = _state.opponentsTeedCount;
  }

  int get _hole => _state.hole;
  String get _wolfKey => _state.wolfKey;

  RoundParticipant? _participant(String key) {
    try {
      return _state.session.participants.firstWhere((p) => p.key == key);
    } catch (_) {
      return null;
    }
  }

  String _nameFor(String key) => _participant(key)?.displayName ?? key;

  int _colorIndex(String key) {
    final order = _state.teeOrder;
    final idx = order.indexOf(key);
    return idx >= 0 ? idx : 0;
  }

  List<String> get _opponentOrder =>
      nonWolfTeeOrder(teeOrder: _state.teeOrder, wolfKey: _wolfKey);

  void _selectBlindWolf() {
    setState(() {
      _selectedCall = const WolfCall(type: WolfCallType.blind);
      _opponentsTeed = 0;
    });
  }

  void _selectPartner(String partnerKey) {
    setState(() {
      _selectedCall = WolfCall(type: WolfCallType.partner, partnerKey: partnerKey);
    });
  }

  void _teeOffOpponent(int index) {
    if (_selectedCall?.type == WolfCallType.blind) return;
    setState(() {
      if (index >= _opponentsTeed) _opponentsTeed = index + 1;
    });
  }

  void _selectLoneWolf() {
    setState(() {
      _selectedCall = const WolfCall(type: WolfCallType.lone);
    });
  }

  Future<void> _continueToScore() async {
    final call = _selectedCall;
    if (call == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose Blind Wolf, a partner, or Lone Wolf')),
      );
      return;
    }
    if (call.type == WolfCallType.partner && (call.partnerKey == null || call.partnerKey!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a partner')),
      );
      return;
    }

    final next = _state.copyWith(
      pendingCall: call,
      opponentsTeedCount: _opponentsTeed,
      currentPhase: WolfInRoundPhase.score,
    );
    await WolfRoundSync.persist(next);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => WolfScoreHoleScreen(state: next),
      ),
    );
  }

  void _openStandings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoundStandingsScreen(state: _state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final par = _state.session.holePars['$_hole'];
    final yardage = _state.session.holeYardages['$_hole'];
    final si = _state.strokeIndexForHole(_hole);
    final wolfName = _nameFor(_wolfKey);
    final isYou = _participant(_wolfKey)?.isYou ?? false;
    final teeOrderLabel = _state.teeOrder.map(_nameFor).join(' → ');

    return Scaffold(
      appBar: BrandAppBar(
        actions: [
          IconButton(
            tooltip: 'Standings',
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: _openStandings,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: AppTheme.screenPadding,
              children: [
                HoleHeader(
                  hole: _hole,
                  par: par,
                  yardage: yardage,
                  strokeIndex: si,
                  thru: _state.holeIndex,
                ),
                SizedBox(height: AppTheme.space4),
                Container(
                  padding: const EdgeInsets.all(AppTheme.space3),
                  decoration: BoxDecoration(
                    color: AppTheme.sand(context).withValues(alpha: 0.13),
                    border: Border.all(color: AppTheme.sand(context).withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: scheme.secondary,
                          borderRadius: BorderRadius.circular(AppTheme.avatarRadius),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'W',
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSecondary,
                          ),
                        ),
                      ),
                      SizedBox(width: AppTheme.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isYou ? "You're the Wolf" : '$wolfName is the Wolf',
                              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              _state.usesTrailingPlayerWolfRule
                                  ? 'LAST PLACE · WOLF'
                                  : 'TEE ORDER · ${teeOrderLabel.toUpperCase()}',
                              style: AppTheme.monoLabel(context, color: scheme.secondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.space4),
                Text(
                  '① BEFORE ANY DRIVE',
                  style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
                ),
                SizedBox(height: AppTheme.space2),
                _ActionRow(
                  title: 'Declare Blind Wolf',
                  subtitle: 'Commit solo, sight unseen.',
                  multiplier: '×3',
                  accent: scheme.secondary,
                  selected: _selectedCall?.type == WolfCallType.blind,
                  onTap: _selectBlindWolf,
                ),
                SizedBox(height: AppTheme.space4),
                Text(
                  '② AS EACH PLAYER TEES OFF · PICK A PARTNER',
                  style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
                ),
                SizedBox(height: AppTheme.space2),
                for (var i = 0; i < _opponentOrder.length; i++)
                  _buildPartnerRow(context, _opponentOrder[i], i),
                SizedBox(height: AppTheme.space4),
                Text(
                  '③ AFTER THE LAST DRIVE',
                  style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
                ),
                SizedBox(height: AppTheme.space2),
                _ActionRow(
                  title: 'Go Lone Wolf',
                  subtitle: _opponentsTeed >= 3 || _selectedCall?.type == WolfCallType.lone
                      ? 'No partner — beat all three.'
                      : 'Available after all players tee off.',
                  multiplier: '×2',
                  accent: scheme.primary,
                  selected: _selectedCall?.type == WolfCallType.lone,
                  enabled: _opponentsTeed >= 3 || _selectedCall?.type == WolfCallType.lone,
                  onTap: _opponentsTeed >= 3
                      ? _selectLoneWolf
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Lone Wolf unlocks after all three opponents have teed off.',
                              ),
                            ),
                          );
                        },
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.pageHorizontal,
              AppTheme.space2,
              AppTheme.pageHorizontal,
              MediaQuery.paddingOf(context).bottom + AppTheme.space4,
            ),
            child: FilledButton(
              onPressed: _continueToScore,
              child: const Text('Score the hole'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerRow(BuildContext context, String key, int index) {
    final scheme = Theme.of(context).colorScheme;
    final name = _nameFor(key);
    final waiting = index > _opponentsTeed;
    final isActive = index == _opponentsTeed && _selectedCall?.type != WolfCallType.blind;
    final isSelected =
        _selectedCall?.type == WolfCallType.partner && _selectedCall?.partnerKey == key;

    if (waiting && !isSelected) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.space2),
        child: OutlinedSurfaceCard(
          borderColor: scheme.outlineVariant.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3, vertical: AppTheme.space2),
          child: Row(
            children: [
              PlayerAvatar(displayName: name, colorIndex: _colorIndex(key), size: 34),
              SizedBox(width: AppTheme.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(color: scheme.onSurfaceVariant)),
                    Text('Yet to tee off', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Text('WAITING', style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space2),
      child: SelectableSurfaceCard(
        selected: isSelected,
        borderColor: isSelected ? scheme.primary : null,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3, vertical: AppTheme.space2),
        child: Row(
          children: [
            PlayerAvatar(displayName: name, colorIndex: _colorIndex(key), size: 34),
            SizedBox(width: AppTheme.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (isActive && !isSelected)
                    Text(
                      'Teeing off — pick partner',
                      style: AppTheme.monoLabel(context, color: scheme.primary),
                    ),
                ],
              ),
            ),
            if (isActive && !isSelected)
              OutlinedButton(
                onPressed: () {
                  _teeOffOpponent(index);
                  _selectPartner(key);
                },
                child: const Text('Partner'),
              )
            else if (isSelected)
              FilledButton(onPressed: null, child: const Text('Partner'))
            else
              OutlinedButton(
                onPressed: () => _selectPartner(key),
                child: const Text('Partner'),
              ),
            if (!isSelected && index < _opponentsTeed)
              IconButton(
                tooltip: 'Mark teed off',
                onPressed: () => _teeOffOpponent(index),
                icon: const Icon(Icons.golf_course_outlined),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.multiplier,
    required this.accent,
    required this.selected,
    this.enabled = true,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String multiplier;
  final Color accent;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = selected
        ? accent
        : accent.withValues(alpha: enabled ? 0.5 : 0.2);

    return SelectableSurfaceCard(
      selected: selected,
      borderColor: borderColor,
      borderRadius: AppTheme.radiusMd,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: enabled ? accent : accent.withValues(alpha: 0.45),
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: enabled ? null : scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Text(
            multiplier,
            style: AppTheme.score(
              context,
              size: 20,
              color: enabled ? accent : accent.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}
