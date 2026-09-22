import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_service.dart';
import '../services/solo_trip_service.dart';
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
                    color: Colors.white.withValues(alpha: 0.05),
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
                            activeTrackColor: OnboardingColors.coral.withValues(alpha: 0.5),
                            thumbColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? OnboardingColors.coral
                                  : Colors.white54,
                            ),
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

                // 1. Instant Notification Test Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await SoloTripService.instance.triggerDebugCheckinNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Test notification sent! Check your notification shade.'),
                            backgroundColor: Colors.teal,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.notifications_active, color: Colors.white),
                    label: Text(
                      'Test Check-in Notification (Instant)',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Solo Trip Live Status & Control Card
                ListenableBuilder(
                  listenable: SoloTripService.instance,
                  builder: (context, _) {
                    final isSoloActive = SoloTripService.instance.isActive;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSoloActive
                            ? const Color(0xFF00E676).withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSoloActive ? const Color(0xFF00E676).withValues(alpha: 0.3) : Colors.white10,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isSoloActive ? Icons.shield : Icons.shield_outlined,
                                color: isSoloActive ? const Color(0xFF00E676) : Colors.white54,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isSoloActive ? 'Solo Trip: ACTIVE' : 'Solo Trip: Inactive',
                                style: GoogleFonts.inter(
                                  color: isSoloActive ? const Color(0xFF00E676) : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (isSoloActive)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await SoloTripService.instance.endSession();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Active Solo Trip ended.')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 18),
                                label: Text(
                                  'End Active Trip',
                                  style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.redAccent),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            )
                          else
                            Text(
                              'Start Solo Trip from the bottom bar or Home Screen to begin automatic check-in tracking.',
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                
                // 3. Restart Onboarding
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
        color: Colors.white.withValues(alpha: 0.05),
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
