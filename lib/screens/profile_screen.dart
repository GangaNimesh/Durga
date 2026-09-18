import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_service.dart';
import '../theme/onboarding_colors.dart';
import 'onboarding_screen.dart';
import 'voice_log_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _alwaysListening = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = await SupabaseService.instance.getUser();
    final voiceSettings = await SupabaseService.instance.getVoiceSettings();
    if (mounted) {
      setState(() {
        _userData = user;
        _alwaysListening = voiceSettings?['always_listening'] ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleVoiceListening(bool val) async {
    setState(() => _alwaysListening = val);
    await SupabaseService.instance.upsertVoiceSettings(alwaysListening: val);
  }

  Future<void> _restartOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', false);
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile & Settings',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: OnboardingColors.coral))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Profile Avatar
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: OnboardingColors.coral, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white12,
                      child: Text(
                        _userData?['full_name']?.isNotEmpty == true
                            ? _userData!['full_name'][0].toUpperCase()
                            : '?',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // User Info Fields
                _buildInfoField('Full Name', _userData?['full_name'] ?? 'Not set', Icons.person),
                const SizedBox(height: 16),
                _buildInfoField('Phone Number', _userData?['phone'] ?? 'Not set', Icons.phone),
                const SizedBox(height: 16),
                _buildInfoField('Email Address', _userData?['email'] ?? 'Not set', Icons.email),
                
                const SizedBox(height: 32),

                // Voice Commands Section
                Text(
                  'VOICE COMMANDS',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Always-listening mode', style: GoogleFonts.inter(color: Colors.white, fontSize: 16)),
                                const SizedBox(height: 2),
                                Text('Allows "Hey Durga" wake word. May impact battery life.', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _alwaysListening,
                            onChanged: _toggleVoiceListening,
                            activeColor: OnboardingColors.coral,
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 20),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VoiceLogScreen()));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('Voice Activity Log', style: GoogleFonts.inter(color: Colors.white, fontSize: 16)),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.white54),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Debug Tools Section
                Text(
                  'DEBUG TOOLS',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _restartOnboarding,
                    icon: const Icon(Icons.restart_alt, color: OnboardingColors.coral),
                    label: Text(
                      'Restart Onboarding',
                      style: GoogleFonts.inter(
                        color: OnboardingColors.coral,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: OnboardingColors.coral),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
