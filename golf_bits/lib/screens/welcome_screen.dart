import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/brand_wordmark.dart';
import '../widgets/outlined_surface_card.dart';
import 'log_in_screen.dart';
import 'sign_up_screen.dart';

/// Splash / onboarding entry: value prop + entry to sign up or log in.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  int _page = 0;

  static const _slides = [
    _Slide(
      icon: Icons.payments_outlined,
      body:
          'Award bits for birdies, chip-ins, sandies and more. Track everything. Settle up after.',
    ),
    _Slide(
      icon: Icons.groups_outlined,
      body:
          'Run rounds with your crew, keep a fair ledger, and make the 19th hole settle-up painless.',
    ),
    _Slide(
      icon: Icons.history_toggle_off_outlined,
      body:
          'Round history stays organised so you can brag with receipts — or quietly improve.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppTheme.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: AppTheme.space6),
              const BrandWordmark(size: BrandWordmarkSize.hero),
              SizedBox(height: AppTheme.space2),
              Text(
                'Track the bits. Win the round.',
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: AppTheme.space8),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final s = _slides[i];
                    return OutlinedSurfaceCard(
                      borderColor: scheme.primary.withValues(alpha: AppTheme.opacityPrimaryBorder),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            s.icon,
                            size: AppTheme.iconIllustration,
                            color: scheme.primary,
                          ),
                          SizedBox(height: AppTheme.space5),
                          Text(
                            s.body,
                            textAlign: TextAlign.center,
                            style: text.bodyLarge?.copyWith(
                              color: scheme.onSurface,
                              height: AppTheme.bodyLineHeightRelaxed,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: AppTheme.space4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: AppTheme.space1),
                    width: active ? AppTheme.pageIndicatorSelected : AppTheme.pageIndicator,
                    height: active ? AppTheme.pageIndicatorSelected : AppTheme.pageIndicator,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? scheme.primary : scheme.outlineVariant,
                    ),
                  );
                }),
              ),
              SizedBox(height: AppTheme.space6),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SignUpScreen(),
                    ),
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Get Started'),
                    SizedBox(width: AppTheme.space2),
                    Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
              SizedBox(height: AppTheme.space3),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LogInScreen(),
                    ),
                  );
                },
                child: const Text('I already have an account'),
              ),
              SizedBox(height: AppTheme.space2),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({required this.icon, required this.body});

  final IconData icon;
  final String body;
}
