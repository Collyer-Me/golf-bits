import 'package:flutter/material.dart';

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

  InputDecoration _decoration(BuildContext context, String hint, {IconData? icon}) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      prefixIcon: icon != null ? Icon(icon, color: scheme.onSurfaceVariant) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.person_add_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Add New Player',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: _decoration(context, 'Enter name…', icon: Icons.badge_outlined),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: _decoration(context, 'Email address (optional)', icon: Icons.mail_outline),
          ),
          const SizedBox(height: 24),
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
  int _teeIndex = 1; // white default

  static const _tees = [
    _TeeVisual('CHAMP', Color(0xFF1A1A1A)),
    _TeeVisual('WHITE', Color(0xFFE8E8E8)),
    _TeeVisual('RED', Color(0xFFB71C1C)),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 24,
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
            const SizedBox(height: 20),
            Text('Round length', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 9, label: Text('9')),
                ButtonSegment(value: 18, label: Text('18')),
              ],
              selected: {_holes},
              onSelectionChanged: (s) => setState(() => _holes = s.first),
            ),
            const SizedBox(height: 20),
            Text('Starting nine', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Front 9')),
                ButtonSegment(value: false, label: Text('Back 9')),
              ],
              selected: {_frontNine},
              onSelectionChanged: (s) => setState(() => _frontNine = s.first),
            ),
            const SizedBox(height: 20),
            Text('Select tee box', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_tees.length, (i) {
                final t = _tees[i];
                final selected = i == _teeIndex;
                return GestureDetector(
                  onTap: () => setState(() => _teeIndex = i),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.color,
                          border: Border.all(
                            color: selected ? scheme.primary : scheme.outlineVariant,
                            width: selected ? 3 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: scheme.primary.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            t.label.isNotEmpty ? t.label[0] : '?',
                            style: TextStyle(
                              color: t.color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(t.label, style: text.labelSmall),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  CourseSetupResult(
                    holes: _holes,
                    frontNineFirst: _frontNine,
                    teeLabel: _tees[_teeIndex].label,
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

  InputDecoration _decoration(BuildContext context, String label, {String? hint, int maxLines = 1}) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom + 24,
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
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              decoration: _decoration(context, 'EVENT NAME', hint: 'e.g. Sandy'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _desc,
              maxLines: 3,
              decoration: _decoration(
                context,
                'DESCRIPTION',
                hint: 'What earns this bit?',
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text('Points', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
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
            const SizedBox(height: 24),
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
