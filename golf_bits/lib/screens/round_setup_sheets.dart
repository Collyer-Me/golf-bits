import 'package:flutter/material.dart';

import '../models/course_catalog_models.dart';
import '../models/custom_event_draft.dart';
import '../theme/app_theme.dart';

/// Bottom sheet: quick-add a player (name + optional email).
Future<void> showAddPlayerSheet(
  BuildContext context, {
  required void Function(String name, String? email) onAdd,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _AddPlayerSheet(onAdd: onAdd),
  );
}

class _AddPlayerSheet extends StatefulWidget {
  const _AddPlayerSheet({required this.onAdd});

  final void Function(String name, String? email) onAdd;

  @override
  State<_AddPlayerSheet> createState() => _AddPlayerSheetState();
}

class _AddPlayerSheetState extends State<_AddPlayerSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.pageHorizontal,
        right: AppTheme.pageHorizontal,
        top: AppTheme.space2,
        bottom: MediaQuery.paddingOf(context).bottom +
            MediaQuery.viewInsetsOf(context).bottom +
            AppTheme.space6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.person_add_outlined, color: Theme.of(context).colorScheme.primary),
              SizedBox(width: AppTheme.space3),
              Text(
                'Add New Player',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SizedBox(height: AppTheme.space5),
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Enter name…',
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          SizedBox(height: AppTheme.buttonPadV),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Email address (optional)',
              prefixIcon: const Icon(Icons.mail_outline),
            ),
          ),
          SizedBox(height: AppTheme.space6),
          FilledButton(
            onPressed: () {
              final n = _name.text.trim();
              if (n.isEmpty) return;
              final e = _email.text.trim();
              Navigator.of(context).pop();
              widget.onAdd(n, e.isEmpty ? null : e);
            },
            child: const Text('Add Player'),
          ),
        ],
      ),
    );
  }
}

/// Result of the course setup sheet (holes, nine, tee).
class CourseSetupResult {
  const CourseSetupResult({
    required this.holes,
    required this.frontNineFirst,
    required this.teeLabel,
    this.courseTeeId,
    required this.coverageLevel,
  });

  final int holes;
  final bool frontNineFirst;
  final String teeLabel;
  final String? courseTeeId;
  final String coverageLevel;
}

/// Bottom sheet: round length, starting nine, tee box.
Future<CourseSetupResult?> showCourseSetupSheet(
  BuildContext context, {
  required String courseName,
  required String coverageLevel,
  List<CourseTeeOption> teeOptions = const [],
}) {
  return showModalBottomSheet<CourseSetupResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _CourseSetupSheet(
      courseName: courseName,
      coverageLevel: coverageLevel,
      teeOptions: teeOptions,
    ),
  );
}

class _CourseSetupSheet extends StatefulWidget {
  const _CourseSetupSheet({
    required this.courseName,
    required this.coverageLevel,
    required this.teeOptions,
  });

  final String courseName;
  final String coverageLevel;
  final List<CourseTeeOption> teeOptions;

  @override
  State<_CourseSetupSheet> createState() => _CourseSetupSheetState();
}

class _CourseSetupSheetState extends State<_CourseSetupSheet> {
  int _holes = 9;
  bool _frontNine = true;
  int _teeIndex = 0;

  List<_TeePickRow> _teePickRows(ColorScheme scheme) {
    if (widget.teeOptions.isEmpty) {
      return [
        _TeePickRow('Championship', null, scheme.surfaceContainerLowest, subtitle: 'Generic'),
        _TeePickRow('White', null, scheme.surfaceContainerHighest, subtitle: 'Generic'),
        _TeePickRow('Red', null, scheme.tertiary, subtitle: 'Generic'),
      ];
    }
    return [
      for (final o in widget.teeOptions)
        _TeePickRow(
          o.label,
          o.id,
          _teeColor(scheme, o.colorHint),
          subtitle: _teeSubtitle(o),
        ),
    ];
  }

  String _teeSubtitle(CourseTeeOption o) {
    final parts = <String>[];
    if (o.totalYardageYds > 0) parts.add('${o.totalYardageYds} yds');
    if (o.holes.isNotEmpty) parts.add('${o.holes.length} holes${o.hasEighteenDistinctHoles ? ' (18-card)' : ''}');
    if (o.courseRating != null || o.slopeRating != null) {
      final r = [
        if (o.courseRating != null) 'CR ${o.courseRating}',
        if (o.slopeRating != null) 'Slope ${o.slopeRating}',
      ].join(' · ');
      parts.add(r);
    }
    return parts.isEmpty ? '' : parts.join(' · ');
  }

  Color _teeColor(ColorScheme scheme, String? hint) {
    final h = (hint ?? '').toLowerCase();
    if (h.contains('black') || h.contains('champ')) return scheme.surfaceContainerLowest;
    if (h.contains('white') || h.contains('blue')) return scheme.surfaceContainerHighest;
    if (h.contains('red') || h.contains('gold')) return scheme.tertiary;
    if (h.contains('green')) return scheme.secondary;
    return scheme.primaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tees = _teePickRows(scheme);
    if (_teeIndex >= tees.length) {
      _teeIndex = 0;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.pageHorizontal,
        right: AppTheme.pageHorizontal,
        top: AppTheme.space2,
        bottom: MediaQuery.paddingOf(context).bottom + AppTheme.space6,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.courseName,
              style: text.titleLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (widget.coverageLevel == CourseCoverageLevel.geoOnly ||
                widget.coverageLevel == CourseCoverageLevel.manual) ...[
              SizedBox(height: AppTheme.space3),
              Text(
                widget.coverageLevel == CourseCoverageLevel.manual
                    ? 'Manual course — tee names are generic until you add scorecard data.'
                    : 'Location only — tee boxes are generic until a scorecard is available.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            SizedBox(height: AppTheme.space5),
            Text('Round length', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: AppTheme.space2),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 9, label: Text('9')),
                ButtonSegment(value: 18, label: Text('18')),
              ],
              selected: {_holes},
              onSelectionChanged: (s) => setState(() => _holes = s.first),
            ),
            SizedBox(height: AppTheme.space5),
            Text('Starting nine', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: AppTheme.space2),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Front 9')),
                ButtonSegment(value: false, label: Text('Back 9')),
              ],
              selected: {_frontNine},
              onSelectionChanged: (s) => setState(() => _frontNine = s.first),
            ),
            SizedBox(height: AppTheme.space5),
            Text('Select tee box', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: AppTheme.space2),
            ...List.generate(tees.length, (i) {
              final t = tees[i];
              final selected = i == _teeIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space1),
                child: Material(
                  color: scheme.surface.withValues(alpha: 0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    onTap: () => setState(() => _teeIndex = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.space2, horizontal: AppTheme.spaceHalf),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: AppTheme.spaceHalf),
                            child: Icon(
                              selected ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: AppTheme.iconDense,
                              color: selected ? scheme.primary : scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: AppTheme.space1),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.label,
                                  style: text.bodyMedium?.copyWith(
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                                if (t.subtitle != null && t.subtitle!.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: AppTheme.spaceHalf),
                                    child: Text(
                                      t.subtitle!,
                                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            SizedBox(height: AppTheme.space7),
            FilledButton(
              onPressed: () {
                final picked = tees[_teeIndex];
                Navigator.of(context).pop(
                  CourseSetupResult(
                    holes: _holes,
                    frontNineFirst: _frontNine,
                    teeLabel: picked.labelDisplay,
                    courseTeeId: picked.courseTeeId,
                    coverageLevel: widget.coverageLevel,
                  ),
                );
              },
              child: const Text('Confirm & continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeePickRow {
  _TeePickRow(this.label, this.courseTeeId, this.color, {this.subtitle});

  final String label;
  final String? courseTeeId;
  final Color color;
  final String? subtitle;

  String get labelDisplay => subtitle == 'Generic' ? label.toUpperCase() : label;
}

/// Quick manual course: name (+ optional city/region line).
Future<ManualCourseDraft?> showManualCourseEntrySheet(BuildContext context) {
  return showModalBottomSheet<ManualCourseDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _ManualCourseSheet(),
  );
}

class ManualCourseDraft {
  const ManualCourseDraft({required this.name, this.subtitle});

  final String name;
  final String? subtitle;
}

class _ManualCourseSheet extends StatefulWidget {
  const _ManualCourseSheet();

  @override
  State<_ManualCourseSheet> createState() => _ManualCourseSheetState();
}

class _ManualCourseSheetState extends State<_ManualCourseSheet> {
  final _name = TextEditingController();
  final _subtitle = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.pageHorizontal,
        right: AppTheme.pageHorizontal,
        top: AppTheme.space2,
        bottom: MediaQuery.paddingOf(context).bottom +
            MediaQuery.viewInsetsOf(context).bottom +
            AppTheme.space6,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Manual course',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: AppTheme.space4),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'COURSE NAME',
                hintText: 'e.g. Springfield Public',
              ),
            ),
            SizedBox(height: AppTheme.buttonPadV),
            TextField(
              controller: _subtitle,
              decoration: const InputDecoration(
                labelText: 'LOCATION (OPTIONAL)',
                hintText: 'City, state / region',
              ),
            ),
            SizedBox(height: AppTheme.space6),
            FilledButton(
              onPressed: () {
                final n = _name.text.trim();
                if (n.isEmpty) return;
                final s = _subtitle.text.trim();
                Navigator.of(context).pop(
                  ManualCourseDraft(name: n, subtitle: s.isEmpty ? null : s),
                );
              },
              child: const Text('Save & use this course'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<CustomEventDraft?> showAddCustomEventSheet(BuildContext context) {
  return showModalBottomSheet<CustomEventDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _AddCustomEventSheet(),
  );
}

class _AddCustomEventSheet extends StatefulWidget {
  const _AddCustomEventSheet();

  @override
  State<_AddCustomEventSheet> createState() => _AddCustomEventSheetState();
}

class _AddCustomEventSheetState extends State<_AddCustomEventSheet> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  int _points = 1;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.pageHorizontal,
        right: AppTheme.pageHorizontal,
        top: AppTheme.space2,
        bottom: MediaQuery.paddingOf(context).bottom +
            MediaQuery.viewInsetsOf(context).bottom +
            AppTheme.space6,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add Custom Event',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: AppTheme.space2),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'EVENT NAME',
                hintText: 'e.g. Sandy',
              ),
            ),
            SizedBox(height: AppTheme.buttonPadV),
            TextField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'DESCRIPTION',
                hintText: 'What earns this bit?',
              ),
            ),
            SizedBox(height: AppTheme.space5),
            Text(
              'Points',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: AppTheme.space2),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => setState(() => _points = (_points - 1).clamp(-5, 10)),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Text(
                    _points >= 0 ? '+$_points' : '$_points',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton.filled(
                  onPressed: () => setState(() => _points = (_points + 1).clamp(-5, 10)),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            SizedBox(height: AppTheme.space6),
            FilledButton(
              onPressed: () {
                final n = _name.text.trim();
                if (n.isEmpty) return;
                Navigator.of(context).pop(
                  CustomEventDraft(
                    name: n,
                    description: _desc.text.trim(),
                    points: _points,
                  ),
                );
              },
              child: const Text('Save Event'),
            ),
          ],
        ),
      ),
    );
  }
}
