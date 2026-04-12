import 'package:flutter/material.dart';

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
  });

  final int holes;
  final bool frontNineFirst;
  final String teeLabel;
}

/// Bottom sheet: round length, starting nine, tee box.
Future<CourseSetupResult?> showCourseSetupSheet(
  BuildContext context, {
  required String courseName,
}) {
  return showModalBottomSheet<CourseSetupResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _CourseSetupSheet(courseName: courseName),
  );
}

class _CourseSetupSheet extends StatefulWidget {
  const _CourseSetupSheet({required this.courseName});

  final String courseName;

  @override
  State<_CourseSetupSheet> createState() => _CourseSetupSheetState();
}

class _CourseSetupSheetState extends State<_CourseSetupSheet> {
  int _holes = 9;
  bool _frontNine = true;
  int _teeIndex = 1;

  List<_TeeVisual> _tees(ColorScheme scheme) => [
        _TeeVisual('CHAMP', scheme.surfaceContainerLowest),
        _TeeVisual('WHITE', scheme.surfaceContainerHighest),
        _TeeVisual('RED', scheme.tertiary),
      ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tees = _tees(scheme);

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
            SizedBox(height: AppTheme.space3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(tees.length, (i) {
                final t = tees[i];
                final selected = i == _teeIndex;
                return GestureDetector(
                  onTap: () => setState(() => _teeIndex = i),
                  child: Column(
                    children: [
                      Container(
                        width: AppTheme.iconHero,
                        height: AppTheme.iconHero,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.color,
                          border: Border.all(
                            color: selected ? scheme.primary : scheme.outlineVariant,
                            width: selected ? AppTheme.selectionRingWidth : AppTheme.outlineBorderWidth,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: scheme.primary.withValues(alpha: AppTheme.opacityPrimaryBorder),
                                    blurRadius: AppTheme.elevationBlurSm,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            t.label.isNotEmpty ? t.label[0] : '?',
                            style: TextStyle(
                              color: AppTheme.textOnFilledCircle(t.color, scheme),
                              fontWeight: FontWeight.w900,
                              fontSize: AppTheme.teeGlyphSize,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: AppTheme.spaceHalf),
                      Text(t.label, style: text.labelSmall),
                    ],
                  ),
                );
              }),
            ),
            SizedBox(height: AppTheme.space7),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  CourseSetupResult(
                    holes: _holes,
                    frontNineFirst: _frontNine,
                    teeLabel: tees[_teeIndex].label,
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

class _TeeVisual {
  const _TeeVisual(this.label, this.color);
  final String label;
  final Color color;
}

/// New custom game event from sheet.
class CustomEventDraft {
  const CustomEventDraft({
    required this.name,
    required this.description,
    required this.points,
  });

  final String name;
  final String description;
  final int points;
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
