import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth/guest_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_wordmark.dart';
import '../widgets/welcome_preview_cards.dart';
import 'log_in_screen.dart';
import 'sign_up_screen.dart';

/// Splash / onboarding entry: value prop carousel + sign up, log in, or guest.
///
/// Always renders in the dark "on course" theme — the brand front door — regardless
/// of the user's [ThemeMode].
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _slideCount = 3;
  static const _autoAdvance = Duration(milliseconds: 4200);

  final PageController _pageController = PageController();
  Timer? _autoAdvanceTimer;
  int _page = 0;

  static const _slides = [
    _WelcomeSlide(
      eyebrow: 'The social golf scorecard',
      headline: 'Tally up.\nSettle up.',
      subcopy:
          'Award bits for birdies, chip-ins and sandies. Track every hole with your mates.',
      preview: WelcomeScorecardPreview(),
    ),
    _WelcomeSlide(
      eyebrow: 'One tap to score',
      headline: 'Award bits\nfor anything.',
      subcopy:
          'Birdies, sandies, greenies, three-putts — tag any side bet with a single tap.',
      preview: WelcomeAwardChipsPreview(),
    ),
    _WelcomeSlide(
      eyebrow: 'No maths required',
      headline: 'See who\nowes who.',
      subcopy:
          'When the round ends, we tally the damage and split the pot automatically.',
      preview: WelcomeSettleUpPreview(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoAdvance());
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    _autoAdvanceTimer = Timer.periodic(_autoAdvance, (_) {
      if (!mounted) return;
      final next = (_page + 1) % _slideCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() => _page = index);
    _startAutoAdvance();
  }

  Future<void> _goToPage(int index) async {
    _startAutoAdvance();
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark(),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final text = Theme.of(context).textTheme;

          return DecoratedBox(
            decoration: AppTheme.welcomeBackgroundDecoration(),
            child: Scaffold(
              backgroundColor: AppColors.darkBg.withValues(alpha: 0),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.welcomeHorizontal,
                    AppTheme.space6,
                    AppTheme.welcomeHorizontal,
                    AppTheme.space4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: BrandWordmark(size: BrandWordmarkSize.welcome),
                      ),
                      SizedBox(height: AppTheme.space7),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _slides.length,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (context, index) => _WelcomeSlideView(slide: _slides[index]),
                        ),
                      ),
                      SizedBox(height: AppTheme.space5),
                      _PageIndicators(
                        count: _slideCount,
                        active: _page,
                        onTap: _goToPage,
                      ),
                      SizedBox(height: AppTheme.space5),
                      _WelcomePrimaryButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Get started', style: text.labelLarge?.copyWith(color: scheme.onPrimary)),
                            const SizedBox(width: AppTheme.space2),
                            Icon(Icons.arrow_forward, size: AppTheme.iconArrow, color: scheme.onPrimary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 11),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const LogInScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(AppTheme.welcomeSecondaryButtonHeight),
                          foregroundColor: scheme.onSurface,
                          side: BorderSide(
                            color: scheme.onSurface.withValues(alpha: AppTheme.opacityWelcomeParchmentBorder),
                            width: AppTheme.emphasisBorderWidth,
                          ),
                        ),
                        child: const Text('I already have an account'),
                      ),
                      const SizedBox(height: AppTheme.space1),
                      TextButton.icon(
                        onPressed: () => showGuestPlayBottomSheet(context),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(30),
                          foregroundColor: scheme.onSurfaceVariant,
                          textStyle: text.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        icon: const Icon(Icons.person_outline, size: 15),
                        label: const Text('Continue as guest'),
                      ),
                      const SizedBox(height: AppTheme.space1),
                      Text(
                        'No account needed to try the app.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmMono(
                          fontSize: 11,
                          letterSpacing: 0.44,
                          color: AppColors.welcomeCaption,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WelcomeSlide {
  const _WelcomeSlide({
    required this.eyebrow,
    required this.headline,
    required this.subcopy,
    required this.preview,
  });

  final String eyebrow;
  final String headline;
  final String subcopy;
  final Widget preview;
}

class _WelcomeSlideView extends StatelessWidget {
  const _WelcomeSlideView({required this.slide});

  final _WelcomeSlide slide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 320;
        final headlineSize = compact ? 36.0 : 46.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slide.eyebrow.toUpperCase(),
                      style: AppTheme.monoLabel(context, color: AppColors.welcomeEyebrow).copyWith(
                        fontSize: 12,
                        letterSpacing: 2.64,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: compact ? AppTheme.space2 : AppTheme.space3),
                    Text(
                      slide.headline,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: headlineSize,
                        fontWeight: FontWeight.w800,
                        height: 0.94,
                        letterSpacing: headlineSize * -0.025,
                        color: scheme.onSurface,
                      ),
                    ),
                    SizedBox(height: compact ? AppTheme.space3 : AppTheme.space4),
                    Text(
                      slide.subcopy,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: compact ? 14 : 15.5,
                            height: 1.5,
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: compact ? AppTheme.space1 : AppTheme.space2),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: slide.preview,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PageIndicators extends StatelessWidget {
  const _PageIndicators({
    required this.count,
    required this.active,
    required this.onTap,
  });

  final int count;
  final int active;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3.5),
          child: Semantics(
            button: true,
            label: 'Slide ${i + 1} of $count',
            selected: isActive,
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: isActive ? AppTheme.pageIndicatorActiveWidth : AppTheme.pageIndicator,
                height: AppTheme.pageIndicatorHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
                  color: isActive
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: AppTheme.opacityWelcomeParchmentDot),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _WelcomePrimaryButton extends StatelessWidget {
  const _WelcomePrimaryButton({required this.onPressed, required this.child});

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
        boxShadow: AppTheme.welcomePrimaryButtonShadow(),
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppTheme.welcomePrimaryButtonHeight),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shadowColor: AppColors.darkBg.withValues(alpha: 0),
        ),
        child: child,
      ),
    );
  }
}
