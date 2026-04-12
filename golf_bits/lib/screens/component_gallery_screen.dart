import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/outlined_surface_card.dart';

/// Scrollable preview of **Material 3** primitives + one approved custom ([OutlinedSurfaceCard]).
class ComponentGalleryScreen extends StatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  State<ComponentGalleryScreen> createState() => _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  int _navIndex = 0;
  bool _birdie = false;
  bool _threePutt = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Style guide & components'),
      ),
      body: ListView(
        padding: AppTheme.screenPadding,
        children: [
          _sectionTitle(context, 'Colour roles', 'Use ColorScheme from Theme — avoid raw hex in screens.'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space4),
              child: Wrap(
                spacing: AppTheme.space3,
                runSpacing: AppTheme.space3,
                children: [
                  _swatch(context, 'Primary', scheme.primary),
                  _swatch(context, 'Secondary', scheme.secondary),
                  _swatch(context, 'Tertiary', scheme.tertiary),
                  _swatch(context, 'Surface', scheme.surface),
                  _swatch(context, 'Accent (token)', AppColors.accentLime),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space6),
          _sectionTitle(context, 'Typography (Lexend)', 'From google_fonts + ThemeData.textTheme.'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Headline', style: text.headlineMedium),
                  Text('Title', style: text.titleMedium),
                  Text('Body on variant', style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                  Text(
                    'LABEL · ALL CAPS',
                    style: text.labelSmall?.copyWith(letterSpacing: AppTheme.letterStepCaps),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space6),
          _sectionTitle(context, 'Buttons', 'Filled / tonal / outlined / text — stadium shape from theme.'),
          Wrap(
            spacing: AppTheme.space3,
            runSpacing: AppTheme.space3,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Primary')),
              FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
              OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
              TextButton(onPressed: () {}, child: const Text('Text')),
            ],
          ),
          const SizedBox(height: AppTheme.space6),
          _sectionTitle(context, 'Search', 'Material SearchBar (theme).'),
          const SearchBar(
            hintText: 'Search',
            leading: Icon(Icons.search),
          ),
          const SizedBox(height: AppTheme.space6),
          _sectionTitle(context, 'Chips', 'Filter-style toggles for events (positive / negative colours).'),
          Wrap(
            spacing: AppTheme.space2,
            runSpacing: AppTheme.space2,
            children: [
              FilterChip(
                label: const Text('Birdie · +1'),
                selected: _birdie,
                onSelected: (v) => setState(() => _birdie = v),
                checkmarkColor: scheme.onPrimary,
              ),
              FilterChip(
                avatar: Icon(Icons.remove_circle_outline, size: AppTheme.iconDense, color: scheme.error),
                label: const Text('Three-putt · −1'),
                selected: _threePutt,
                onSelected: (v) => setState(() => _threePutt = v),
                side: BorderSide(
                  color: scheme.error.withValues(alpha: AppTheme.opacityBorderEmphasis),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space6),
          _sectionTitle(context, 'Cards', 'Default Card + OutlinedSurfaceCard (accent border).'),
          OutlinedSurfaceCard(
            borderColor: scheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ROUND IN PROGRESS', style: text.labelSmall?.copyWith(color: scheme.primary)),
                Text('Royal Melbourne', style: text.headlineSmall),
                Text('West course · 18 holes', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: AppTheme.space3),
                Wrap(
                  spacing: AppTheme.space2,
                  children: [
                    Chip(
                      avatar: Icon(Icons.person, size: AppTheme.iconDense, color: scheme.onSurfaceVariant),
                      label: const Text('Alex'),
                    ),
                    Chip(
                      avatar: Icon(Icons.person, size: AppTheme.iconDense, color: scheme.onSurfaceVariant),
                      label: const Text('Jordan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space3),
          const Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('A')),
              title: Text('Inactive row'),
              subtitle: Text('Uses ListTile — no custom widget'),
              trailing: Icon(Icons.add),
            ),
          ),
          const SizedBox(height: AppTheme.space6),
          _sectionTitle(context, 'FAB', 'Standard FAB + extended pattern.'),
          Row(
            children: [
              FloatingActionButton(
                onPressed: () {},
                child: const Icon(Icons.edit),
              ),
              const SizedBox(width: AppTheme.space4),
              FloatingActionButton.extended(
                onPressed: () {},
                icon: const Icon(Icons.edit),
                label: const Text('Label'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space6),
          _sectionTitle(context, 'Bottom sheet', 'Modal sheet with Material padding.'),
          FilledButton.tonal(
            onPressed: () => _showEventSheet(context),
            child: const Text('Open sample event sheet'),
          ),
          SizedBox(height: AppTheme.space8 * 3),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'People'),
          NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String subtitle) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium?.copyWith(color: scheme.primary)),
          Text(subtitle, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _swatch(BuildContext context, String label, Color color) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppTheme.iconLarge,
          height: AppTheme.iconLarge,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: AppTheme.opacityBorderEmphasis)),
          ),
        ),
        const SizedBox(height: AppTheme.space1),
        SizedBox(
          width: AppTheme.space8 * 2 + AppTheme.space3,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: text.labelSmall,
          ),
        ),
      ],
    );
  }

  void _showEventSheet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppTheme.pageHorizontal,
            right: AppTheme.pageHorizontal,
            top: AppTheme.space2,
            bottom: MediaQuery.paddingOf(ctx).bottom + AppTheme.space6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Alex',
                      style: text.headlineSmall?.copyWith(
                        color: scheme.primary,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    child: const Icon(Icons.check),
                  ),
                ],
              ),
              Text(
                'SELECT EVENTS TO AWARD BITS',
                style: text.labelSmall?.copyWith(
                  letterSpacing: AppTheme.letterSheetLabel,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              Wrap(
                spacing: AppTheme.space2,
                runSpacing: AppTheme.space2,
                alignment: WrapAlignment.center,
                children: [
                  ActionChip(label: const Text('Birdie +1'), onPressed: () {}),
                  ActionChip(label: const Text('Eagle +2'), onPressed: () {}),
                  ActionChip(
                    label: const Text('Three-putt −1'),
                    onPressed: () {},
                    backgroundColor: scheme.errorContainer,
                    labelStyle: TextStyle(color: scheme.onErrorContainer),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
