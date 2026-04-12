import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'component_gallery_screen.dart';
import 'round_setup_screen.dart';

/// Home entry — link to the living style / component preview.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag, size: AppTheme.iconInline, color: theme.colorScheme.primary),
            SizedBox(width: AppTheme.space2),
            Text(
              'Golf Bits',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flag_outlined,
                size: AppTheme.iconHero,
                color: theme.colorScheme.primary,
              ),
              SizedBox(height: AppTheme.space6),
              Text(
                'Material 3 shell',
                style: theme.textTheme.headlineSmall,
              ),
              SizedBox(height: AppTheme.space2),
              Text(
                'Open the gallery to preview colours, type, buttons, chips, navigation, and sheets.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: AppTheme.space6),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RoundSetupScreen(),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, size: AppTheme.iconInline),
                    SizedBox(width: AppTheme.space25),
                    Text('Start new round'),
                  ],
                ),
              ),
              SizedBox(height: AppTheme.space3),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ComponentGalleryScreen(),
                    ),
                  );
                },
                child: const Text('Style guide & components'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
