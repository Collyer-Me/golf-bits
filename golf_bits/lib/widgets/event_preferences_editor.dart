import 'package:flutter/material.dart';

import '../models/event_preferences.dart';
import '../screens/round_setup_sheets.dart';
import '../theme/app_theme.dart';
import 'outlined_surface_card.dart';

class EventPreferencesEditor extends StatefulWidget {
  const EventPreferencesEditor({
    super.key,
    required this.events,
    required this.onChanged,
  });

  final List<EventPreference> events;
  final ValueChanged<List<EventPreference>> onChanged;

  @override
  State<EventPreferencesEditor> createState() => _EventPreferencesEditorState();
}

class _EventPreferencesEditorState extends State<EventPreferencesEditor>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateEvent(EventPreference updated) {
    final next = [
      for (final event in widget.events)
        if (event.id == updated.id) updated else event,
    ];
    widget.onChanged(next);
  }

  Future<void> _editNickname(EventPreference event) async {
    final controller = TextEditingController(text: event.nickname ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Set nickname for ${event.name}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'e.g. NTP, Bomb, Sandy',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null) return;
    _updateEvent(event.copyWith(nickname: result.isEmpty ? null : result));
  }

  Future<void> _addCustomEvent() async {
    final draft = await showAddCustomEventSheet(context);
    if (!mounted || draft == null) return;
    final next = [...widget.events, eventPreferenceFromCustomDraft(draft)];
    widget.onChanged(next);
    _tabController.index = 1;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final preset = widget.events.where((e) => !e.isCustom).toList();
    final custom = widget.events.where((e) => e.isCustom).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Preset events'),
            Tab(text: 'Custom events'),
          ],
        ),
        const SizedBox(height: AppTheme.space2),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _eventList(context, preset, scheme, text),
              _eventList(context, custom, scheme, text, emptyCustom: true),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space2),
        OutlinedButton.icon(
          onPressed: _addCustomEvent,
          icon: Icon(Icons.add, color: scheme.primary),
          label: Text('Add custom event', style: TextStyle(color: scheme.primary)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: scheme.primary.withValues(alpha: AppTheme.opacityBorderEmphasis),
              width: AppTheme.chipOutlineWidth,
            ),
          ),
        ),
      ],
    );
  }

  Widget _eventList(
    BuildContext context,
    List<EventPreference> rows,
    ColorScheme scheme,
    TextTheme text, {
    bool emptyCustom = false,
  }) {
    if (rows.isEmpty && emptyCustom) {
      return Center(
        child: Text(
          'No custom events yet.\nTap “Add custom event” below.',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: AppTheme.space2),
      children: rows
          .map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space3),
              child: _EventPreferenceCard(
                event: event,
                scheme: scheme,
                text: text,
                onToggleEnabled: (v) => _updateEvent(event.copyWith(enabled: v)),
                onDecrementPoints: () => _updateEvent(
                      event.copyWith(points: (event.points - 1).clamp(-5, 10)),
                    ),
                onIncrementPoints: () => _updateEvent(
                      event.copyWith(points: (event.points + 1).clamp(-5, 10)),
                    ),
                onEditNickname: () => _editNickname(event),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EventPreferenceCard extends StatelessWidget {
  const _EventPreferenceCard({
    required this.event,
    required this.scheme,
    required this.text,
    required this.onToggleEnabled,
    required this.onDecrementPoints,
    required this.onIncrementPoints,
    required this.onEditNickname,
  });

  final EventPreference event;
  final ColorScheme scheme;
  final TextTheme text;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onDecrementPoints;
  final VoidCallback onIncrementPoints;
  final VoidCallback onEditNickname;

  TextStyle _sectionLabel(TextTheme theme) {
    return (theme.labelSmall ?? theme.bodySmall!).copyWith(
      color: scheme.onSurfaceVariant,
      letterSpacing: AppTheme.letterStepCaps,
      fontWeight: FontWeight.w600,
    );
  }

  String get _nicknameLine {
    final n = event.nickname?.trim();
    if (n == null || n.isEmpty) return '';
    return n.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final mutedBody = scheme.onSurfaceVariant;
    final pointsLabelStyle = text.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: scheme.onPrimaryContainer,
    );
    final stepperEnabled = event.enabled;

    return OutlinedSurfaceCard(
      borderColor: scheme.outlineVariant,
      padding: const EdgeInsets.all(AppTheme.cardInnerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  event.name,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: event.nickname?.isNotEmpty == true ? 'Edit nickname' : 'Set nickname',
                onPressed: onEditNickname,
                icon: Icon(
                  Icons.edit_outlined,
                  size: AppTheme.iconDense,
                  color: mutedBody,
                ),
              ),
            ],
          ),
          if (_nicknameLine.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceHalf),
            Text(
              _nicknameLine,
              style: text.labelSmall?.copyWith(
                color: mutedBody,
                letterSpacing: AppTheme.letterStepCaps,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.space5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACTIVE STATUS', style: _sectionLabel(text)),
                    const SizedBox(height: AppTheme.space2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Switch(
                        value: event.enabled,
                        onChanged: onToggleEnabled,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('POINTS MODIFIER', style: _sectionLabel(text)),
                    const SizedBox(height: AppTheme.space2),
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: scheme.outlineVariant,
                            width: AppTheme.outlineBorderWidth,
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: stepperEnabled ? onDecrementPoints : null,
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.remove,
                                color: mutedBody,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                event.points >= 0 ? '+${event.points}' : '${event.points}',
                                textAlign: TextAlign.center,
                                style: pointsLabelStyle,
                              ),
                            ),
                            IconButton(
                              onPressed: stepperEnabled ? onIncrementPoints : null,
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.add,
                                color: mutedBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space5),
          Divider(
            height: AppTheme.space1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: AppTheme.opacitySecondaryBorder),
          ),
          const SizedBox(height: AppTheme.space5),
          Text(
            event.description,
            style: text.bodySmall?.copyWith(
              color: mutedBody,
              height: AppTheme.bodyLineHeightRelaxed,
            ),
          ),
        ],
      ),
    );
  }
}
