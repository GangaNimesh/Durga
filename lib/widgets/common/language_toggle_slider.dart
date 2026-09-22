import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';

class LanguageToggleSlider extends StatelessWidget {
  final bool isCompact;

  const LanguageToggleSlider({
    super.key,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isTelugu = localeProvider.isTelugu;

    final width = isCompact ? 108.0 : 138.0;
    final height = isCompact ? 34.0 : 36.0;
    final thumbWidth = (width - 6) / 2;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        localeProvider.toggleLanguage();
      },
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1424).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Sliding animated thumb
            AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              alignment: isTelugu ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: thumbWidth,
                height: height - 6,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF5E62),
                      Color(0xFFFF7E40),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5E62).withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),

            // Labels row
            Row(
              children: [
                // English label
                Expanded(
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: GoogleFonts.inter(
                        fontSize: isCompact ? 12.5 : 13.5,
                        fontWeight: !isTelugu ? FontWeight.bold : FontWeight.w500,
                        color: !isTelugu ? Colors.white : Colors.white60,
                        letterSpacing: 0.3,
                      ),
                      child: Text(isCompact ? 'EN' : 'English'),
                    ),
                  ),
                ),

                // Telugu label
                Expanded(
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: GoogleFonts.notoSansTelugu(
                        fontSize: isCompact ? 13 : 13.5,
                        fontWeight: isTelugu ? FontWeight.bold : FontWeight.w500,
                        color: isTelugu ? Colors.white : Colors.white60,
                      ),
                      child: Text(isCompact ? 'తె' : 'తెలుగు'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
