import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/onboarding_colors.dart';

/// Abstract line-art illustration for onboarding slide 1.
///
/// Draws a coral-ringed circle containing a minimal protection motif:
/// two soft overlapping curves suggesting a shield / embrace, plus subtle
/// radiating pulse arcs to convey "always connected / alert".
///
/// Entirely code-drawn via [CustomPainter] — no image assets required.
class ProtectionIllustration extends StatelessWidget {
  const ProtectionIllustration({super.key, this.size = 110});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _ProtectionPainter(),
      ),
    );
  }
}

class _ProtectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // ── 1. Filled inner circle ──────────────────────────────────────────
    final fillPaint = Paint()
      ..color = const Color(0xFF3A2228)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.82, fillPaint);

    // ── 2. Outer coral ring ─────────────────────────────────────────────
    final ringPaint = Paint()
      ..color = OnboardingColors.coral.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius * 0.92, ringPaint);

    // ── 3. Abstract shield / embrace curves ─────────────────────────────
    final iconPaint = Paint()
      ..color = OnboardingColors.coral.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final cx = center.dx;
    final cy = center.dy;
    final s = radius * 0.42; // scale factor for the icon

    // Left curve — a soft protective arc
    final leftPath = Path()
      ..moveTo(cx - s * 0.05, cy - s * 0.9)
      ..cubicTo(
        cx - s * 1.1, cy - s * 0.5, // control point 1
        cx - s * 1.1, cy + s * 0.7,  // control point 2
        cx, cy + s * 1.0,            // end
      );
    canvas.drawPath(leftPath, iconPaint);

    // Right curve — mirrors left, overlapping at bottom
    final rightPath = Path()
      ..moveTo(cx + s * 0.05, cy - s * 0.9)
      ..cubicTo(
        cx + s * 1.1, cy - s * 0.5,
        cx + s * 1.1, cy + s * 0.7,
        cx, cy + s * 1.0,
      );
    canvas.drawPath(rightPath, iconPaint);

    // Small connecting arc at top — the "clasp" of the embrace
    final topArc = Path()
      ..moveTo(cx - s * 0.05, cy - s * 0.9)
      ..quadraticBezierTo(cx, cy - s * 1.1, cx + s * 0.05, cy - s * 0.9);
    canvas.drawPath(topArc, iconPaint);

    // ── 4. Radiating pulse arcs (top-right) ─────────────────────────────
    for (int i = 0; i < 3; i++) {
      final arcPaint = Paint()
        ..color = OnboardingColors.coral.withValues(alpha: 0.15 + i * 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;

      final arcRadius = radius * (0.50 + i * 0.12);
      const startAngle = -math.pi / 3; // ~60° from top
      const sweepAngle = math.pi / 5;  // ~36° arc

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: arcRadius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
