import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/onboarding_colors.dart';
import 'page_indicator.dart';

/// Reusable layout for a single onboarding slide.
///
/// Accepts a headline, body text, an illustration widget, and a CTA button.
/// The [illustration] is placed either above or below the headline depending
/// on [illustrationAboveHeadline] (slide 2's form sits above the headline).
///
/// A subtle radial gradient is layered behind the content for depth.
class OnboardingPageLayout extends StatelessWidget {
  const OnboardingPageLayout({
    super.key,
    required this.illustration,
    required this.headline,
    required this.body,
    required this.buttonLabel,
    required this.onButtonPressed,
    this.currentPage = 0,
    this.pageIndex = 0,
    this.totalPages = 3,
    this.skipLabel,
    this.onSkip,
    this.showSkip = true,
    this.illustrationAboveHeadline = true,
    this.onDotTapped,
    this.belowBodyContent,
  });

  final Widget illustration;
  final String headline;
  final String body;
  final String buttonLabel;
  final VoidCallback onButtonPressed;
  final int currentPage;
  final int pageIndex;
  final int totalPages;
  final String? skipLabel;
  final VoidCallback? onSkip;
  final bool showSkip;
  final bool illustrationAboveHeadline;
  final ValueChanged<int>? onDotTapped;

  /// Optional content that appears below the body text (e.g. contact cards on
  /// slide 3). Scrollable area includes this.
  final Widget? belowBodyContent;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: OnboardingColors.background,
      ),
      child: Stack(
        children: [
          // ── Subtle radial glow for depth ────────────────────────────────
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    OnboardingColors.glowCenter.withValues(alpha: 0.45),
                    OnboardingColors.background.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // ── Main content ────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Skip link ─────────────────────────────────────────────
                if (showSkip)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, right: 24),
                      child: GestureDetector(
                        onTap: onSkip,
                        child: Text(
                          skipLabel ?? 'Skip',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: OnboardingColors.skip,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 44), // keep consistent top spacing

                // ── Scrollable middle area ────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (illustrationAboveHeadline) ...[
                          const SizedBox(height: 32),
                          illustration,
                          const SizedBox(height: 36),
                        ],

                        // ── Headline ──────────────────────────────────────
                        Text(
                          headline,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 42,
                            fontWeight: FontWeight.w500,
                            color: OnboardingColors.headline,
                            height: 1.12,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Body ──────────────────────────────────────────
                        Text(
                          body,
                          style: GoogleFonts.inter(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w400,
                            color: OnboardingColors.body,
                            height: 1.55,
                          ),
                        ),

                        if (!illustrationAboveHeadline) ...[
                          const SizedBox(height: 28),
                          illustration,
                        ],

                        if (belowBodyContent != null) ...[
                          const SizedBox(height: 28),
                          belowBodyContent!,
                        ],

                        // Extra bottom space so content doesn't collide with
                        // the pinned bottom section.
                        const SizedBox(height: 24),
                      ],
                    ).animate(target: currentPage == pageIndex ? 1 : 0)
                     .fade(duration: 500.ms)
                     .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                  ),
                ),

                // ── Bottom section (dots + button) ────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    28,
                    16,
                    28,
                    bottomPadding + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Page indicator
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PageIndicator(
                          currentPage: currentPage,
                          totalPages: totalPages,
                          onDotTapped: onDotTapped,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // CTA button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: onButtonPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: OnboardingColors.coral,
                            foregroundColor: OnboardingColors.coralText,
                            elevation: 0,
                            shape: const StadiumBorder(),
                            textStyle: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          child: Text(buttonLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
