import 'package:flutter/material.dart';

import '../../theme/onboarding_colors.dart';

/// Horizontal page-indicator dots for the onboarding carousel.
///
/// The active page is shown as an elongated coral pill; inactive pages as
/// small muted circles.
class PageIndicator extends StatelessWidget {
  const PageIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onDotTapped,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int>? onDotTapped;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalPages, (index) {
        final bool isActive = index == currentPage;
        return GestureDetector(
          onTap: () {
            if (onDotTapped != null) {
              onDotTapped!(index);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? OnboardingColors.coral : OnboardingColors.dotInactive,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
