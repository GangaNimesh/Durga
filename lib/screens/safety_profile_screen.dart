import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/supabase_service.dart';
import '../theme/onboarding_colors.dart';

class SafetyProfileScreen extends StatefulWidget {
  const SafetyProfileScreen({super.key});

  @override
  State<SafetyProfileScreen> createState() => _SafetyProfileScreenState();
}

class _SafetyProfileScreenState extends State<SafetyProfileScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  // Step 1: Medical Info
  String? _bloodGroup;
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final List<String> _conditions = [];
  final TextEditingController _notesController = TextEditingController();

  final List<String> _availableConditions = [
    'Diabetes',
    'Asthma',
    'Heart Disease',
    'Hypertension',
    'Epilepsy',
    'None'
  ];

  final List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  // Step 2: Permissions (state managed locally via permission_handler status)
  final Map<Permission, bool> _permissionStatus = {
    Permission.contacts: false,
    Permission.notification: false,
    Permission.camera: false,
    Permission.microphone: false,
    Permission.location: false,
    Permission.photos: false,
  };

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    for (var perm in _permissionStatus.keys) {
      final status = await perm.status;
      setState(() {
        _permissionStatus[perm] = status.isGranted;
      });
    }
  }

  Future<void> _requestPermission(Permission perm) async {
    final status = await perm.request();
    setState(() {
      _permissionStatus[perm] = status.isGranted;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _finishProfile() async {
    setState(() => _isSaving = true);
    try {
      await SupabaseService.instance.upsertMedicalProfile(
        bloodGroup: _bloodGroup,
        allergies: _allergiesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        medications: _medicationsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        medicalConditions: _conditions,
        emergencyNotes: _notesController.text,
      );

      await SupabaseService.instance.updatePermissions(
        contacts: _permissionStatus[Permission.contacts],
        notifications: _permissionStatus[Permission.notification],
        camera: _permissionStatus[Permission.camera],
        microphone: _permissionStatus[Permission.microphone],
        location: _permissionStatus[Permission.location],
        gallery: _permissionStatus[Permission.photos],
      );

      await SupabaseService.instance.markSafetyProfileComplete();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _prevStep,
        ),
        title: Text(
          'Safety Profile',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentStep = i),
              children: [
                _buildMedicalStep(),
                _buildPermissionsStep(),
                _buildCompleteStep(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: index <= _currentStep ? OnboardingColors.coral : Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isSaving ? null : (_currentStep == 2 ? _finishProfile : _nextStep),
          style: ElevatedButton.styleFrom(
            backgroundColor: OnboardingColors.coral,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          child: _isSaving
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  _currentStep == 2 ? 'Finish & Save' : 'Continue',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: OnboardingColors.coralText,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Step 1: Medical Info ──

  Widget _buildMedicalStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medical Information',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Crucial for first responders in an emergency.',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 24),
          
          _buildLabel('Blood Group'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _bloodGroups.map((bg) => ChoiceChip(
              label: Text(bg),
              selected: _bloodGroup == bg,
              onSelected: (val) => setState(() => _bloodGroup = val ? bg : null),
              selectedColor: OnboardingColors.coral.withValues(alpha: 0.2),
              backgroundColor: Colors.black45,
              side: BorderSide(color: _bloodGroup == bg ? OnboardingColors.coral : Colors.white24),
              showCheckmark: false,
              labelStyle: TextStyle(color: _bloodGroup == bg ? OnboardingColors.coral : Colors.white),
            )).toList(),
          ),
          const SizedBox(height: 20),

          _buildLabel('Allergies (comma separated)'),
          _buildTextField(_allergiesController, 'e.g., Peanuts, Penicillin'),
          const SizedBox(height: 20),

          _buildLabel('Current Medications'),
          _buildTextField(_medicationsController, 'e.g., Insulin, Inhaler'),
          const SizedBox(height: 20),

          _buildLabel('Medical Conditions'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableConditions.map((c) {
              final isSelected = _conditions.contains(c);
              return FilterChip(
                label: Text(c),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _conditions.add(c);
                    } else {
                      _conditions.remove(c);
                    }
                  });
                },
                selectedColor: OnboardingColors.coral.withValues(alpha: 0.2),
                backgroundColor: Colors.black45,
                side: BorderSide(color: isSelected ? OnboardingColors.coral : Colors.white24),
                showCheckmark: false,
                labelStyle: TextStyle(color: isSelected ? OnboardingColors.coral : Colors.white),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          _buildLabel('Emergency Notes'),
          _buildTextField(_notesController, 'Any other critical info...', maxLines: 3),
        ],
      ),
    );
  }

  // ── Step 2: Permissions ──

  Widget _buildPermissionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'App Permissions',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'We need these to keep you safe.',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 24),
          
          _buildPermissionTile(Icons.location_on, 'Location', 'For SOS alerts and journey tracking.', Permission.location),
          _buildPermissionTile(Icons.contacts, 'Contacts', 'To pick emergency contacts.', Permission.contacts),
          _buildPermissionTile(Icons.mic, 'Microphone', 'For silent audio recording.', Permission.microphone),
          _buildPermissionTile(Icons.notifications, 'Notifications', 'To send alerts and updates.', Permission.notification),
          _buildPermissionTile(Icons.camera_alt, 'Camera', 'For capturing evidence.', Permission.camera),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(IconData icon, String title, String subtitle, Permission perm) {
    final isGranted = _permissionStatus[perm] ?? false;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isGranted ? Colors.green.withValues(alpha: 0.2) : Colors.white10,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isGranted ? Colors.green : Colors.white, size: 24),
      ),
      title: Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
      trailing: isGranted
          ? const Icon(Icons.check_circle, color: Colors.green)
          : TextButton(
              onPressed: () => _requestPermission(perm),
              child: const Text('Allow', style: TextStyle(color: OnboardingColors.coral)),
            ),
    );
  }

  // ── Step 3: Complete ──

  Widget _buildCompleteStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user, size: 80, color: OnboardingColors.coral),
          const SizedBox(height: 24),
          Text(
            'Profile Complete',
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'Your safety profile is now 100% complete. First responders will have the context they need.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
