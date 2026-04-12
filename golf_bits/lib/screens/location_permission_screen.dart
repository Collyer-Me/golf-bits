import 'package:flutter/material.dart';

import '../navigation/auth_navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/outlined_surface_card.dart';

/// Post–sign-up prompt: explain location + CTA (stub — no platform permission call yet).
class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => openAppHome(context),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: AppTheme.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: AppTheme.space4),
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: AppTheme.opacityHeroGlow),
                        blurRadius: AppTheme.locationGlowBlur,
                        spreadRadius: AppTheme.locationGlowSpread,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: AppTheme.iconHero,
                    backgroundColor: scheme.surfaceContainerHigh,
                    child: Icon(Icons.location_on, size: AppTheme.iconHero, color: scheme.primary),
                  ),
                ),
              ),
              SizedBox(height: AppTheme.space8),
              Text(
                'Play smarter, not harder',
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: AppTheme.space3),
              Text(
                'Location helps pick the right course and tee box automatically, '
                'so you spend less time tapping and more time swinging.',
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: AppTheme.bodyLineHeightRelaxed,
                ),
              ),
              SizedBox(height: AppTheme.space7),
              OutlinedSurfaceCard(
                borderColor: scheme.outlineVariant,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Automatic tee selection',
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: AppTheme.space3),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.map_outlined,
                            size: AppTheme.iconLarge,
                            color: scheme.primary.withValues(alpha: AppTheme.opacityMutedPrimary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location permission will hook to geolocator / web API'),
                    ),
                  );
                  openAppHome(context);
                },
                child: const Text('Allow Location'),
              ),
              SizedBox(height: AppTheme.space3),
              TextButton(
                onPressed: () => openAppHome(context),
                child: const Text('Not now'),
              ),
              SizedBox(height: AppTheme.space2),
            ],
          ),
        ),
      ),
    );
  }
}
