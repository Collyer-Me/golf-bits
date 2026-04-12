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
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _swatch('Primary', scheme.primary),
                  _swatch('Secondary', scheme.secondary),
                  _swatch('Tertiary', scheme.tertiary),
                  _swatch('Surface', scheme.surface),
                  _swatch('Accent (token)', AppColors.accentLime),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Typography (Lexend)', 'From google_fonts + ThemeData.textTheme.'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Headline', style: text.headlineMedium),
                  Text('Title', style: text.titleMedium),
                  Text('Body on variant', style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                  Text('LABEL · ALL CAPS', style: text.labelSmall?.copyWith(letterSpacing: 1.2)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Buttons', 'Filled / tonal / outlined / text — stadium shape from theme.'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Primary')),
              FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
              OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
              TextButton(onPressed: () {}, child: const Text('Text')),
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Search', 'Material SearchBar (theme).'),
          const SearchBar(
            hintText: 'Search',
            leading: Icon(Icons.search),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Chips', 'Filter-style toggles for events (positive / negative colours).'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Birdie · +1'),
                selected: _birdie,
                onSelected: (v) => setState(() => _birdie = v),
                checkmarkColor: scheme.onPrimary,
              ),
              FilterChip(
                avatar: Icon(Icons.remove_circle_outline, size: 18, color: scheme.error),
                label: const Text('Three-putt · −1'),
                selected: _threePutt,
                onSelected: (v) => setState(() => _threePutt = v),
                side: BorderSide(color: scheme.error.withOpacity(0.55)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Cards', 'Default Card + OutlinedSurfaceCard (accent border).'),
          OutlinedSurfaceCard(
            borderColor: scheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ROUND IN PROGRESS', style: text.labelSmall?.copyWith(color: scheme.primary)),
                Text('Royal Melbourne', style: text.headlineSmall),
                Text('West course · 18 holes', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(Icons.person, size: 18, color: scheme.onSurfaceVariant),
                      label: const Text('Alex'),
                    ),
                    Chip(
                      avatar: Icon(Icons.person, size: 18, color: scheme.onSurfaceVariant),
                      label: const Text('Jordan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('A')),
              title: Text('Inactive row'),
              subtitle: Text('Uses ListTile — no custom widget'),
              trailing: Icon(Icons.add),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'FAB', 'Standard FAB + extended pattern.'),
          Row(
            children: [
              FloatingActionButton(
                onPressed: () {},
                child: const Icon(Icons.edit),
              ),
              const SizedBox(width: 16),
              FloatingActionButton.extended(
                onPressed: () {},
                icon: const Icon(Icons.edit),
                label: const Text('Label'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Bottom sheet', 'Modal sheet with Material padding.'),
          FilledButton.tonal(
            onPressed: () => _showEventSheet(context),
            child: const Text('Open sample event sheet'),
          ),
          const SizedBox(height: 100),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium?.copyWith(color: scheme.primary)),
          Text(subtitle, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _swatch(String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(width: 72, child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
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
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.paddingOf(ctx).bottom + 24,
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
                style: text.labelSmall?.copyWith(letterSpacing: 1.1, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
