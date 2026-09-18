import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/onboarding_colors.dart';

/// Parsed structure of an assistant legal response
class ParsedLegalResponse {
  final String summary;
  final String? emergency;
  final List<ProcedureStep> steps;
  final List<LegalLawItem> laws;
  final List<String> faqs;

  ParsedLegalResponse({
    required this.summary,
    this.emergency,
    this.steps = const [],
    this.laws = const [],
    this.faqs = const [],
  });
}

class ProcedureStep {
  final int number;
  final String title;
  final String detail;

  ProcedureStep({
    required this.number,
    required this.title,
    required this.detail,
  });
}

class LegalLawItem {
  final String section;
  final String detail;

  LegalLawItem({
    required this.section,
    required this.detail,
  });
}

/// Intelligent parser that handles both tagged output and standard markdown
class LegalResponseParser {
  static ParsedLegalResponse parse(String raw) {
    if (raw.contains('[SUMMARY]') || raw.contains('[STEPS]') || raw.contains('[LAWS]')) {
      return _parseTagged(raw);
    }
    return _parseMarkdown(raw);
  }

  static ParsedLegalResponse _parseTagged(String raw) {
    String summary = '';
    String? emergency;
    final List<ProcedureStep> steps = [];
    final List<LegalLawItem> laws = [];
    final List<String> faqs = [];

    // Extract emergency
    if (raw.contains('[EMERGENCY]')) {
      final part = raw.split('[EMERGENCY]')[1];
      final content = part.split(RegExp(r'\[[A-Z]+\]'))[0].trim();
      if (content.isNotEmpty) emergency = content;
    }

    // Extract summary
    if (raw.contains('[SUMMARY]')) {
      final part = raw.split('[SUMMARY]')[1];
      summary = part.split(RegExp(r'\[[A-Z]+\]'))[0].trim();
    }

    // Extract steps
    if (raw.contains('[STEPS]')) {
      final part = raw.split('[STEPS]')[1];
      final stepsText = part.split(RegExp(r'\[[A-Z]+\]'))[0].trim();
      int stepNum = 1;
      for (final line in stepsText.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        // Matches "1. Title: Detail" or "- Title: Detail" or "1. Title | Detail"
        final cleaned = trimmed.replaceFirst(RegExp(r'^(\d+[\.\)]|\-|\*)\s*'), '');
        String title = cleaned;
        String detail = '';

        if (cleaned.contains(':')) {
          final idx = cleaned.indexOf(':');
          title = cleaned.substring(0, idx).trim();
          detail = cleaned.substring(idx + 1).trim();
        } else if (cleaned.contains('|')) {
          final idx = cleaned.indexOf('|');
          title = cleaned.substring(0, idx).trim();
          detail = cleaned.substring(idx + 1).trim();
        }

        steps.add(ProcedureStep(
          number: stepNum++,
          title: title.replaceAll('**', ''),
          detail: detail.replaceAll('**', ''),
        ));
      }
    }

    // Extract laws
    if (raw.contains('[LAWS]')) {
      final part = raw.split('[LAWS]')[1];
      final lawsText = part.split(RegExp(r'\[[A-Z]+\]'))[0].trim();
      for (final line in lawsText.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final cleaned = trimmed.replaceFirst(RegExp(r'^(\d+[\.\)]|\-|\*)\s*'), '');
        String section = cleaned;
        String detail = '';

        if (cleaned.contains(':')) {
          final idx = cleaned.indexOf(':');
          section = cleaned.substring(0, idx).trim();
          detail = cleaned.substring(idx + 1).trim();
        } else if (cleaned.contains('|')) {
          final idx = cleaned.indexOf('|');
          section = cleaned.substring(0, idx).trim();
          detail = cleaned.substring(idx + 1).trim();
        }

        laws.add(LegalLawItem(
          section: section.replaceAll('**', ''),
          detail: detail.replaceAll('**', ''),
        ));
      }
    }

    // Extract FAQs
    if (raw.contains('[FAQS]')) {
      final part = raw.split('[FAQS]')[1];
      final faqsText = part.split(RegExp(r'\[[A-Z]+\]'))[0].trim();
      for (final line in faqsText.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final q = trimmed.replaceFirst(RegExp(r'^(\d+[\.\)]|\-|\*)\s*'), '').replaceAll('**', '').trim();
        if (q.isNotEmpty) faqs.add(q);
      }
    }

    if (summary.isEmpty && raw.isNotEmpty) {
      summary = raw.split('[')[0].trim();
    }

    return ParsedLegalResponse(
      summary: summary.isNotEmpty ? summary : raw,
      emergency: emergency,
      steps: steps,
      laws: laws,
      faqs: faqs,
    );
  }

  /// Fallback parser for standard markdown responses
  static ParsedLegalResponse _parseMarkdown(String raw) {
    final lines = raw.split('\n');
    final List<String> summaryLines = [];
    final List<ProcedureStep> steps = [];
    final List<LegalLawItem> laws = [];
    final List<String> faqs = [];
    String? emergency;

    bool inSteps = false;
    bool inLaws = false;
    bool inFaqs = false;
    int stepNum = 1;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final lower = trimmed.toLowerCase();

      // Detect emergency
      if (lower.contains('112') || lower.contains('181') || lower.contains('emergency')) {
        if (lower.contains('call') || lower.contains('dial')) {
          emergency = trimmed.replaceAll('#', '').replaceAll('*', '').trim();
        }
      }

      // Detect section headers
      if (lower.contains('step') || lower.contains('procedure') || lower.contains('how to')) {
        inSteps = true;
        inLaws = false;
        inFaqs = false;
        continue;
      } else if (lower.contains('law') || lower.contains('section') || lower.contains('legal') || lower.contains('act')) {
        inLaws = true;
        inSteps = false;
        inFaqs = false;
        continue;
      } else if (lower.contains('faq') || lower.contains('question') || lower.contains('related')) {
        inFaqs = true;
        inSteps = false;
        inLaws = false;
        continue;
      }

      // Parse numbered steps
      if (RegExp(r'^\d+[\.\)]\s+').hasMatch(trimmed) || inSteps) {
        final match = RegExp(r'^\d+[\.\)]\s*(.*)').firstMatch(trimmed);
        final content = match != null ? match.group(1)! : trimmed.replaceFirst(RegExp(r'^\-\s*'), '');

        String title = content;
        String detail = '';
        if (content.contains(':')) {
          final idx = content.indexOf(':');
          title = content.substring(0, idx).trim();
          detail = content.substring(idx + 1).trim();
        }

        steps.add(ProcedureStep(
          number: stepNum++,
          title: title.replaceAll('**', ''),
          detail: detail.replaceAll('**', ''),
        ));
        continue;
      }

      // Parse laws
      if (inLaws || lower.contains('section ') || lower.contains(' act')) {
        final cleaned = trimmed.replaceFirst(RegExp(r'^[\-\*]\s*'), '');
        String sec = cleaned;
        String det = '';
        if (cleaned.contains(':')) {
          final idx = cleaned.indexOf(':');
          sec = cleaned.substring(0, idx).trim();
          det = cleaned.substring(idx + 1).trim();
        }
        laws.add(LegalLawItem(section: sec.replaceAll('**', ''), detail: det.replaceAll('**', '')));
        continue;
      }

      // Parse questions
      if (inFaqs || (trimmed.endsWith('?') && (trimmed.startsWith('-') || trimmed.startsWith('*')))) {
        faqs.add(trimmed.replaceFirst(RegExp(r'^[\-\*\d\.]\s*'), '').replaceAll('**', '').trim());
        continue;
      }

      if (!inSteps && !inLaws && !inFaqs) {
        summaryLines.add(trimmed.replaceAll('**', '').replaceAll('###', '').replaceAll('##', ''));
      }
    }

    final summary = summaryLines.join(' ');

    return ParsedLegalResponse(
      summary: summary.isNotEmpty ? summary : raw,
      emergency: emergency,
      steps: steps,
      laws: laws,
      faqs: faqs,
    );
  }
}

/// A super modern, collapsible card that presents legal advice with clarity
class LegalResponseCard extends StatelessWidget {
  final String rawResponse;
  final ValueChanged<String>? onFaqSelected;

  const LegalResponseCard({
    super.key,
    required this.rawResponse,
    this.onFaqSelected,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = LegalResponseParser.parse(rawResponse);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Emergency Alert (if applicable) ──
        if (parsed.emergency != null) ...[
          _buildEmergencyBanner(parsed.emergency!),
          const SizedBox(height: 10),
        ],

        // ── Direct Summary / Takeaway ──
        Text(
          parsed.summary,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 14.5,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),

        // ── Step-by-Step Procedure Dropdown ──
        if (parsed.steps.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CollapsibleSection(
            icon: Icons.format_list_numbered_rounded,
            iconColor: OnboardingColors.coral,
            title: 'Step-by-Step Procedure',
            subtitle: '${parsed.steps.length} practical steps',
            child: Column(
              children: parsed.steps.map((step) => _buildStepItem(step)).toList(),
            ),
          ),
        ],

        // ── Applicable Laws & Rights Dropdown ──
        if (parsed.laws.isNotEmpty) ...[
          const SizedBox(height: 10),
          _CollapsibleSection(
            icon: Icons.balance_rounded,
            iconColor: Colors.tealAccent,
            title: 'Relevant Laws & Your Rights',
            subtitle: '${parsed.laws.length} legal provisions',
            child: Column(
              children: parsed.laws.map((law) => _buildLawItem(law)).toList(),
            ),
          ),
        ],

        // ── Further FAQs & Follow-up Questions Dropdown ──
        if (parsed.faqs.isNotEmpty) ...[
          const SizedBox(height: 10),
          _CollapsibleSection(
            icon: Icons.help_outline_rounded,
            iconColor: Colors.amberAccent,
            title: 'Related FAQs & Next Questions',
            subtitle: 'Tap any question to ask AI',
            initiallyExpanded: true,
            child: Column(
              children: parsed.faqs.map((q) => _buildFaqItem(q)).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmergencyBanner(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: Colors.redAccent.shade100,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: () async {
              final uri = Uri.parse('tel:112');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'CALL 112',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(ProcedureStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OnboardingColors.coral.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(color: OnboardingColors.coral.withValues(alpha: 0.5)),
            ),
            child: Text(
              '${step.number}',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (step.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    step.detail,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLawItem(LegalLawItem law) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel_rounded, size: 16, color: Colors.tealAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  law.section,
                  style: GoogleFonts.inter(
                    color: Colors.tealAccent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (law.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    law.detail,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question) {
    return InkWell(
      onTap: () => onFaqSelected?.call(question),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: OnboardingColors.coral.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: OnboardingColors.coral),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                question,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

/// An animated collapsible dropdown container with smooth rotation and modern styling
class _CollapsibleSection extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;
  final bool initiallyExpanded;

  const _CollapsibleSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animController;
  late Animation<double> _rotationAnim;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: _isExpanded ? 1.0 : 0.0,
    );
    _rotationAnim = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.iconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RotationTransition(
                    turns: _rotationAnim,
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12, top: 4),
              child: widget.child,
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 240),
          ),
        ],
      ),
    );
  }
}
