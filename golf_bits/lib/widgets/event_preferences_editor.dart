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
              child: OutlinedSurfaceCard(
                borderColor: scheme.outlineVariant,
                padding: const EdgeInsets.all(AppTheme.buttonPadV),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Switch(
                          value: event.enabled,
                          onChanged: (v) => _updateEvent(event.copyWith(enabled: v)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.displayLabel,
                                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (event.nickname != null && event.nickname!.isNotEmpty) ...[
                                const SizedBox(height: AppTheme.spaceHalf),
                                Text(
                                  'Original: ${event.name}',
                                  style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                              const SizedBox(height: AppTheme.space1),
                              Text(
                                event.description,
                                style: text.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: AppTheme.bodyLineHeightTight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _editNickname(event),
                        icon: const Icon(Icons.edit_outlined, size: AppTheme.iconDense),
                        label: Text(event.nickname?.isNotEmpty == true ? 'Edit nickname' : 'Set nickname'),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton.filledTonal(
                          onPressed: event.enabled
                              ? () => _updateEvent(
                                    event.copyWith(points: (event.points - 1).clamp(-5, 10)),
                                  )
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
                          child: Text(
                            event.points >= 0 ? '+${event.points}' : '${event.points}',
                            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton.filled(
                          onPressed: event.enabled
                              ? () => _updateEvent(
                                    event.copyWith(points: (event.points + 1).clamp(-5, 10)),
                                  )
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
