import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';
import '../theme/onboarding_colors.dart';
import 'new_home_screen.dart';
import '../widgets/onboarding/onboarding_page_layout.dart';
import 'contact_picker_screen.dart';
import '../widgets/onboarding/protection_illustration.dart';
import '../services/supabase_service.dart';

/// Key used in [SharedPreferences] to track whether onboarding has been shown.
const String _kOnboardingCompleteKey = 'onboarding_complete';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingCompleteKey) ?? false;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOnboardingCompleteKey);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  // Form controllers for Slide 2
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // State for Slide 3
  List<Map<String, String>> _selectedContacts = [];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _onDotTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _pickContact() async {
    final picked = await Navigator.of(context).push<Contact>(
      MaterialPageRoute(builder: (_) => const ContactPickerScreen()),
    );
    if (picked != null && picked.phones.isNotEmpty) {
      if (_selectedContacts.length < 3) {
        setState(() {
          _selectedContacts.add({
            'name': picked.displayName,
            'phone': picked.phones.first.number,
          });
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 3 contacts allowed.')),
        );
      }
    }
  }

  void _removeContact(int index) {
    setState(() {
      _selectedContacts.removeAt(index);
    });
  }

  Future<void> _finishOnboarding() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // 1. Ensure user exists
      await SupabaseService.instance.getOrCreateUser();

      // 2. Update user profile
      await SupabaseService.instance.updateUser(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
      );

      // 3. Save selected contacts
      for (final c in _selectedContacts) {
        await SupabaseService.instance.addEmergencyContact(
          name: c['name'] ?? '',
          phone: c['phone'] ?? '',
        );
      }

      // 4. Mark complete
      await SupabaseService.instance.markOnboardingComplete();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOnboardingCompleteKey, true);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const NewHomeScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving details: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            physics: const ClampingScrollPhysics(),
            children: [
              _buildSlide1(),
              _buildSlide2(),
              _buildSlide3(),
            ],
          ),
          if (_isSaving)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: OnboardingColors.coral)),
            ),
        ],
      ),
    );
  }

  Widget _buildSlide1() {
    final locale = Provider.of<LocaleProvider>(context);
    return OnboardingPageLayout(
      pageIndex: 0,
      currentPage: _currentPage,
      onDotTapped: _onDotTapped,
      onSkip: _finishOnboarding,
      skipLabel: locale.tr('onboarding_skip'),
      headline: locale.tr('onboarding_slide1_title'),
      body: locale.tr('onboarding_slide1_body'),
      buttonLabel: locale.tr('onboarding_get_started'),
      onButtonPressed: _nextPage,
      illustration: const ProtectionIllustration(size: 110),
    );
  }

  Widget _buildSlide2() {
    final locale = Provider.of<LocaleProvider>(context);
    return OnboardingPageLayout(
      pageIndex: 1,
      currentPage: _currentPage,
      onDotTapped: _onDotTapped,
      onSkip: _finishOnboarding,
      skipLabel: locale.tr('onboarding_skip'),
      headline: locale.tr('onboarding_slide2_title'),
      body: locale.tr('onboarding_slide2_body'),
      buttonLabel: locale.tr('onboarding_continue'),
      onButtonPressed: _nextPage,
      illustrationAboveHeadline: true,
      illustration: _Slide2Form(
        nameController: _nameController,
        phoneController: _phoneController,
        emailController: _emailController,
      ),
    );
  }

  Widget _buildSlide3() {
    final locale = Provider.of<LocaleProvider>(context);
    return OnboardingPageLayout(
      pageIndex: 2,
      currentPage: _currentPage,
      onDotTapped: _onDotTapped,
      onSkip: _finishOnboarding,
      skipLabel: locale.tr('onboarding_later'),
      headline: locale.tr('onboarding_slide3_title'),
      body: locale.tr('onboarding_slide3_body'),
      buttonLabel: locale.tr('onboarding_finish_setup'),
      onButtonPressed: _finishOnboarding,
      illustrationAboveHeadline: false,
      belowBodyContent: _Slide3Contacts(
        contacts: _selectedContacts,
        onAddPressed: _pickContact,
        onRemovePressed: _removeContact,
      ),
      illustration: const SizedBox.shrink(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SLIDE 2 — Functional Form
// ═══════════════════════════════════════════════════════════════════════════

class _Slide2Form extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;

  const _Slide2Form({
    required this.nameController,
    required this.phoneController,
    required this.emailController,
  });

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        color: OnboardingColors.body,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        fontSize: 15,
        color: OnboardingColors.headline.withValues(alpha: 0.3),
      ),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: OnboardingColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: OnboardingColors.inputBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: OnboardingColors.coral, width: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(locale.tr('onboarding_full_name')),
        const SizedBox(height: 8),
        TextField(
          controller: nameController,
          style: GoogleFonts.inter(color: OnboardingColors.headline, fontSize: 15),
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(locale.tr('onboarding_full_name_hint')),
        ),
        const SizedBox(height: 16),

        _buildLabel(locale.tr('onboarding_phone')),
        const SizedBox(height: 8),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          style: GoogleFonts.inter(color: OnboardingColors.headline, fontSize: 15),
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(
            '98765 43210',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: OnboardingColors.coral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'IN +91',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: OnboardingColors.coral,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        _buildLabel(locale.tr('onboarding_email')),
        const SizedBox(height: 8),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.inter(color: OnboardingColors.headline, fontSize: 15),
          decoration: _inputDecoration(locale.tr('onboarding_email_hint')),
        ),
        const SizedBox(height: 12),

        Text(
          locale.tr('onboarding_slide2_body'),
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: OnboardingColors.body.withValues(alpha: 0.7),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SLIDE 3 — Trusted contacts UI
// ═══════════════════════════════════════════════════════════════════════════

class _Slide3Contacts extends StatelessWidget {
  final List<Map<String, String>> contacts;
  final VoidCallback onAddPressed;
  final Function(int) onRemovePressed;

  const _Slide3Contacts({
    required this.contacts,
    required this.onAddPressed,
    required this.onRemovePressed,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);
    return Column(
      children: [
        GestureDetector(
          onTap: onAddPressed,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: OnboardingColors.coral.withValues(alpha: 0.5),
              borderRadius: 16,
              dashWidth: 6,
              dashGap: 4,
              strokeWidth: 1.5,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Icon(
                    Icons.add,
                    size: 28,
                    color: OnboardingColors.coral.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    locale.tr('onboarding_add_trusted_contact'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: OnboardingColors.body,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        ...contacts.asMap().entries.map((entry) {
          final idx = entry.key;
          final contact = entry.value;
          final initials = contact['name'] != null && contact['name']!.isNotEmpty
              ? contact['name']!.substring(0, 1).toUpperCase()
              : '#';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: OnboardingColors.contactCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: OnboardingColors.inputBorder.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: OnboardingColors.coral,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: OnboardingColors.coralText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact['name'] ?? 'Unknown',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: OnboardingColors.headline,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          contact['phone'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: OnboardingColors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onRemovePressed(idx),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: OnboardingColors.body.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Dashed border painter ────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    this.dashWidth = 5,
    this.dashGap = 3,
    this.strokeWidth = 1.5,
  });

  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0, metric.length).toDouble();
        final extracted = metric.extractPath(distance, end);
        canvas.drawPath(extracted, paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      color != old.color ||
      borderRadius != old.borderRadius ||
      dashWidth != old.dashWidth ||
      dashGap != old.dashGap ||
      strokeWidth != old.strokeWidth;
}
