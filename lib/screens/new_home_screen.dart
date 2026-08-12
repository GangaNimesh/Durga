import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_service.dart';
import '../theme/onboarding_colors.dart'; // Reusing the dark plum theme for consistency
import '../widgets/home/manage_contacts_sheet.dart';
import '../services/silent_recorder.dart';
import 'fake_call_screen.dart';
import 'profile_screen.dart';
import 'safety_profile_screen.dart';
import 'instant_video_screen.dart';

class NewHomeScreen extends StatefulWidget {
  const NewHomeScreen({super.key});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _sosPulseController;
  late Animation<double> _sosPulseAnimation;
  
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _activeContacts = [];
  int _safetyScore = 0;
  bool _isLoading = true;
  bool _isRecording = false;
  bool _helplinesExpanded = false;

  @override
  void initState() {
    super.initState();
    _sosPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _sosPulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _sosPulseController, curve: Curves.easeInOut),
    );

    _loadData();
  }

  @override
  void dispose() {
    _sosPulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await SupabaseService.instance.getUser();
      final contacts = await SupabaseService.instance.getActiveContacts();
      final score = await SupabaseService.instance.getSafetyProfilePercentage();
      
      if (mounted) {
        setState(() {
          _user = user;
          _activeContacts = contacts;
          _safetyScore = score;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _triggerSOS() async {
    final Uri telUrl = Uri.parse('tel:100');
    if (await canLaunchUrl(telUrl)) {
      await launchUrl(telUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A0A14), // Deep plum background
        body: Center(child: CircularProgressIndicator(color: OnboardingColors.coral)),
      );
    }

    final name = _user?['full_name'] ?? 'User';
    final firstName = name.split(' ').first;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFF1A0A14), // Matching the mockup's dark background
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Status Pills Row ──
                    Row(
                      children: [
                        _buildStatusPill(
                          icon: Icons.shield_outlined,
                          text: 'Profile $_safetyScore%',
                          iconColor: Colors.green,
                          onTap: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SafetyProfileScreen()),
                            );
                            if (result == true) {
                              _loadData();
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildStatusPill(
                          icon: Icons.people_outline,
                          text: '${_activeContacts.length} contacts',
                          iconColor: Colors.blueAccent,
                          showDot: true,
                          onTap: () async {
                            await ManageContactsSheet.show(context);
                            _loadData();
                          },
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ProfileScreen()),
                            );
                          },
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white24,
                            child: Text(
                              initial,
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // ── Greeting ──
                    Text(
                      'Hi, $firstName',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your safety is our priority today.',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── SOS Button ──
                    Center(
                      child: GestureDetector(
                        onLongPress: _triggerSOS,
                        child: AnimatedBuilder(
                          animation: _sosPulseAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: OnboardingColors.coral.withValues(alpha: 0.1),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: 220 * (_sosPulseAnimation.value - 0.1),
                                height: 220 * (_sosPulseAnimation.value - 0.1),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: OnboardingColors.coral.withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: OnboardingColors.coral,
                                    boxShadow: [
                                      BoxShadow(
                                        color: OnboardingColors.coral.withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.white),
                                      const SizedBox(height: 8),
                                      Text(
                                        'HOLD FOR\nSOS',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Trusted Contacts Card ──
                    _buildCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trusted Contacts',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _activeContacts.isEmpty
                                    ? Text('No contacts added', style: GoogleFonts.inter(color: Colors.white54))
                                    : Row(
                                        children: _activeContacts.asMap().entries.map((e) {
                                          final i = e.key;
                                          final name = e.value['name'] as String;
                                          final init = name.isNotEmpty ? name[0].toUpperCase() : '#';
                                          
                                          // Cycle through 4 different colors
                                          final colors = const [
                                            Colors.teal, 
                                            Colors.orange, 
                                            Colors.purple, 
                                            Colors.blueAccent
                                          ];
                                          final avatarColor = colors[i % colors.length];

                                          return Transform.translate(
                                            offset: Offset(i * -10.0, 0),
                                            child: CircleAvatar(
                                              radius: 18,
                                              backgroundColor: avatarColor,
                                              child: Text(init, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await ManageContactsSheet.show(context);
                              _loadData();
                            },
                            child: Text(
                              'Manage',
                              style: GoogleFonts.inter(color: OnboardingColors.coral, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Nearest Help Card ──
                    _buildCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _buildHelpRow(Icons.local_police, 'Police Station', '2.4 km'),
                          const Divider(height: 1, color: Colors.black12),
                          _buildHelpRow(Icons.local_hospital, 'Hospital', '3.1 km'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Emergency Helplines ──
                    _buildCard(
                      padding: EdgeInsets.zero,
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          onExpansionChanged: (val) => setState(() => _helplinesExpanded = val),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: const Icon(Icons.phone_in_talk, color: Colors.white),
                          title: Text(
                            'Emergency Helplines',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          trailing: Icon(
                            _helplinesExpanded ? Icons.expand_less : Icons.chevron_right,
                            color: Colors.white54,
                          ),
                          children: [
                            _buildHelplineRow('National Emergency', '112'),
                            _buildHelplineRow('Police', '100'),
                            _buildHelplineRow('Women Helpline', '181'),
                            _buildHelplineRow('Ambulance', '108'),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            
            // ── Sticky Bottom Quick Action Bar ──
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickAction(Icons.phone_in_talk, 'Fake Call', () {
                     Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FakeCallScreen()));
                  }, color: Colors.white.withValues(alpha: 0.15)),
                  
                  _buildQuickAction(
                    _isRecording ? Icons.stop : Icons.mic, 
                    _isRecording ? 'Recording' : 'Record', 
                    () async {
                      if (_isRecording) {
                        final path = await SilentRecorder.instance.stopRecording();
                        setState(() => _isRecording = false);
                        if (mounted && path != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Saved to: $path')),
                          );
                        }
                      } else {
                        await SilentRecorder.instance.startRecording();
                        setState(() => _isRecording = SilentRecorder.instance.isRecording);
                      }
                    },
                    color: _isRecording ? Colors.red : Colors.white.withValues(alpha: 0.15),
                    iconColor: _isRecording ? Colors.white : Colors.white,
                  ),
                  
                  _buildQuickAction(Icons.location_on, 'Share Trip', () {
                    // Future feature
                  }, color: Colors.white.withValues(alpha: 0.15)),
                  
                  _buildQuickAction(Icons.videocam, 'Video Rec', () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const InstantVideoScreen()),
                    );
                  }, color: Colors.white.withValues(alpha: 0.15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill({
    required IconData icon,
    required String text,
    required Color iconColor,
    bool showDot = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              text,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            if (showDot) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  Widget _buildHelpRow(IconData icon, String title, String distance) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(distance, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.white54),
        ],
      ),
      onTap: () {
        // Open map
      },
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap, {Color? color, Color? iconColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color ?? Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor ?? Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHelplineRow(String title, String number) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 0),
      title: Text(title, style: GoogleFonts.inter(color: Colors.white)),
      trailing: Text(
        number, 
        style: GoogleFonts.inter(
          color: OnboardingColors.coral, 
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      onTap: () async {
        final Uri telUrl = Uri.parse('tel:$number');
        if (await canLaunchUrl(telUrl)) {
          await launchUrl(telUrl);
        }
      },
    );
  }
}
