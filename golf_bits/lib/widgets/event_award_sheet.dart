import 'package:flutter/material.dart';

import '../models/round_session_args.dart';
import '../theme/app_theme.dart';

typedef EventAwardCallback = void Function(String label, int delta, String iconKey);

enum AwardChipVisual { sand, fairwayFilled, fairwayOutline, junk }

class EventDef {
  const EventDef(this.label, this.delta, this.iconKey);
  final String label;
  final int delta;
  final String iconKey;
}

AwardChipVisual chipVisualForPositive(EventDef event, List<int> tiers) {
  final rank = tiers.indexOf(event.delta);
  if (rank == 0) return AwardChipVisual.sand;
  if (rank == 1) return AwardChipVisual.fairwayFilled;
  return AwardChipVisual.fairwayOutline;
}

class EventAwardSheet extends StatefulWidget {
  const EventAwardSheet({
    super.key,
    required this.playerName,
    required this.hole,
    required this.par,
    required this.rules,
    required this.initialSelectedKeys,
    required this.onAward,
    this.subtitle,
    this.runsAlongsideWolf = false,
    this.participantOptions,
    this.selectedParticipantKey,
    this.onParticipantSelected,
  });

  final String playerName;
  final int hole;
  final int? par;
  final List<RoundEventRule> rules;
  final Set<String> initialSelectedKeys;
  final EventAwardCallback onAward;
  final String? subtitle;
  final bool runsAlongsideWolf;
  final List<RoundParticipant>? participantOptions;
  final String? selectedParticipantKey;
  final ValueChanged<String>? onParticipantSelected;

  @override
  State<EventAwardSheet> createState() => _EventAwardSheetState();
}

class _EventAwardSheetState extends State<EventAwardSheet> {
  late final Set<String> _selectedKeys;

  @override
  void initState() {
    super.initState();
    _selectedKeys = {...widget.initialSelectedKeys};
  }

  static String eventKey(String label, int delta) => '$label::$delta';

  void _toggle(EventDef e) {
    setState(() {
      final key = eventKey(e.label, e.delta);
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
    });
    widget.onAward(e.label, e.delta, e.iconKey);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final mapped = (widget.rules.isEmpty
            ? [
                const RoundEventRule(label: 'Birdie', delta: 1, iconKey: 'sports_golf'),
                const RoundEventRule(label: 'Eagle', delta: 2, iconKey: 'trending_up'),
                const RoundEventRule(label: 'Chip-in', delta: 1, iconKey: 'flag_outlined'),
                const RoundEventRule(label: 'One-Putt', delta: 1, iconKey: 'radio_button_checked_outlined'),
                const RoundEventRule(label: 'Three-Putt', delta: -1, iconKey: 'remove_circle_outline'),
                const RoundEventRule(label: 'Water Hazard', delta: -1, iconKey: 'waves_outlined'),
              ]
            : widget.rules)
        .map((r) => EventDef(r.label, r.delta, r.iconKey))
        .toList();
    final positive = mapped.where((e) => e.delta >= 0).toList()
      ..sort((a, b) => b.delta.compareTo(a.delta));
    final negative = mapped.where((e) => e.delta < 0).toList()
      ..sort((a, b) => a.delta.compareTo(b.delta));

    final positiveTiers = positive.map((e) => e.delta).toSet().toList()..sort((a, b) => b.compareTo(a));

    final headerSubtitle = widget.subtitle ??
        (widget.par != null
            ? 'HOLE ${widget.hole} · PAR ${widget.par}'.toUpperCase()
            : 'HOLE ${widget.hole}'.toUpperCase());

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.pageHorizontal,
        right: AppTheme.pageHorizontal,
        top: AppTheme.space2,
        bottom: MediaQuery.paddingOf(context).bottom + AppTheme.space6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Award to ${widget.playerName}',
                      style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      headerSubtitle,
                      style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (widget.runsAlongsideWolf)
                Padding(
                  padding: const EdgeInsets.only(left: AppTheme.space2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space2,
                      vertical: AppTheme.space1,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.16),
                      border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
                    ),
                    child: Text(
                      'RUNS ALONGSIDE WOLF',
                      style: AppTheme.monoLabel(context, color: AppTheme.bits(context)).copyWith(fontSize: 9),
                    ),
                  ),
                ),
              Tooltip(
                message: 'Done',
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.check),
                ),
              ),
            ],
          ),
          if (widget.participantOptions != null && widget.onParticipantSelected != null) ...[
            SizedBox(height: AppTheme.space4),
            Text('WHO?', style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant)),
            SizedBox(height: AppTheme.space2),
            Row(
              children: [
                for (final p in widget.participantOptions!)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceHalf),
                      child: _ParticipantPickerTile(
                        participant: p,
                        selected: p.key == widget.selectedParticipantKey,
                        onTap: () => widget.onParticipantSelected!(p.key),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          SizedBox(height: AppTheme.space5),
          if (positive.isNotEmpty) ...[
            Text('BITS WON', style: AppTheme.monoLabel(context, color: AppTheme.bits(context))),
            SizedBox(height: AppTheme.space2),
            Wrap(
              spacing: AppTheme.space2,
              runSpacing: AppTheme.space2,
              children: [
                for (final e in positive)
                  AwardEventChip(
                    event: e,
                    selected: _selectedKeys.contains(eventKey(e.label, e.delta)),
                    visual: chipVisualForPositive(e, positiveTiers),
                    onTap: () => _toggle(e),
                  ),
              ],
            ),
          ],
          if (negative.isNotEmpty) ...[
            SizedBox(height: AppTheme.space4),
            Text(
              'JUNK · BITS LOST',
              style: AppTheme.monoLabel(context, color: AppTheme.junk(context)),
            ),
            SizedBox(height: AppTheme.space2),
            Wrap(
              spacing: AppTheme.space2,
              runSpacing: AppTheme.space2,
              children: [
                for (final e in negative)
                  AwardEventChip(
                    event: e,
                    selected: _selectedKeys.contains(eventKey(e.label, e.delta)),
                    visual: AwardChipVisual.junk,
                    onTap: () => _toggle(e),
                  ),
              ],
            ),
          ],
          SizedBox(height: AppTheme.space5),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _ParticipantPickerTile extends StatelessWidget {
  const _ParticipantPickerTile({
    required this.participant,
    required this.selected,
    required this.onTap,
  });

  final RoundParticipant participant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? AppTheme.emphasisBorderWidth : AppTheme.outlineBorderWidth,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.space2),
          child: Column(
            children: [
              Text(
                participant.displayName.isNotEmpty
                    ? participant.displayName.substring(0, 1).toUpperCase()
                    : '?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                participant.displayName,
                style: Theme.of(context).textTheme.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AwardEventChip extends StatelessWidget {
  const AwardEventChip({
    super.key,
    required this.event,
    required this.selected,
    required this.visual,
    required this.onTap,
  });

  final EventDef event;
  final bool selected;
  final AwardChipVisual visual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final deltaStr = event.delta >= 0 ? '+${event.delta}' : '${event.delta}';
    final radius = BorderRadius.circular(AppTheme.stadiumRadius);

    late final Color bg;
    late final Color fg;
    BorderSide? border;

    switch (visual) {
      case AwardChipVisual.sand:
        bg = scheme.secondary;
        fg = scheme.onSecondary;
      case AwardChipVisual.fairwayFilled:
        bg = scheme.primary;
        fg = scheme.onPrimary;
      case AwardChipVisual.fairwayOutline:
        if (selected) {
          bg = scheme.primary;
          fg = scheme.onPrimary;
        } else {
          bg = scheme.primary.withValues(alpha: AppTheme.opacityFairwayChipFill);
          fg = scheme.primary;
          border = BorderSide(
            color: scheme.primary.withValues(alpha: AppTheme.opacityFairwayChipBorder),
            width: AppTheme.chipOutlineWidth,
          );
        }
      case AwardChipVisual.junk:
        if (selected) {
          bg = scheme.error;
          fg = scheme.onError;
        } else {
          bg = scheme.error.withValues(alpha: AppTheme.opacityJunkChipFill);
          fg = scheme.error;
          border = BorderSide(
            color: scheme.error.withValues(alpha: AppTheme.opacityJunkChipBorder),
            width: AppTheme.chipOutlineWidth,
          );
        }
    }

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: radius, side: border ?? BorderSide.none),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space4,
            vertical: AppTheme.space2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.label,
                style: text.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: fg),
              ),
              SizedBox(width: AppTheme.spaceHalf),
              Text(deltaStr, style: AppTheme.monoLabel(context, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showEventAwardSheet({
  required BuildContext context,
  required EventAwardSheet sheet,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => sheet,
  );
}
