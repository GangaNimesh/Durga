import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_service.dart';
import '../theme/onboarding_colors.dart';
import '../widgets/home/manage_contacts_sheet.dart';
import '../services/silent_recorder.dart';
import 'fake_call_screen.dart';
import 'profile_screen.dart';
import 'safety_profile_screen.dart';
import 'instant_video_screen.dart';
import '../widgets/voice/voice_command_overlay.dart';
import '../services/voice_intent.dart';
import '../services/voice_command_service.dart';
import 'solo_trip_screen.dart';
import '../widgets/chat/legal_chat_view.dart';

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

  // Volume button long-press detection
  DateTime? _volumeDownPressTime;
  static const _longPressDuration = Duration(milliseconds: 800);

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

    // Register volume button listener
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);

    _loadData();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _sosPulseController.dispose();
    super.dispose();
  }

  /// Intercept volume-down long press to trigger voice commands
  bool _handleHardwareKey(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
      if (event is KeyDownEvent) {
        _volumeDownPressTime = DateTime.now();
        // Schedule a check after the long-press duration
        Future.delayed(_longPressDuration, () {
          if (_volumeDownPressTime != null && mounted) {
            final elapsed = DateTime.now().difference(_volumeDownPressTime!);
            if (elapsed >= _longPressDuration) {
              _volumeDownPressTime = null;
              _showVoiceOverlay();
            }
          }
        });
      } else if (event is KeyUpEvent) {
        _volumeDownPressTime = null;
      }
    }
    return false; // Don't consume the event, let volume still change
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

  void _showVoiceOverlay() {
    showGeneralDialog(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) {
        return VoiceCommandOverlay(
          onDismiss: () => Navigator.of(context).pop(),
          onIntentConfirmed: (intent) {
            Navigator.of(context).pop();
            _executeVoiceIntent(intent);
          },
        );
      },
    );
  }

  void _executeVoiceIntent(VoiceIntent intent) async {
    // Log the voice command to Supabase
    try {
      await VoiceCommandService.instance.executeIntent(intent, context);
    } catch (e) {
      debugPrint("Voice logging error: $e");
    }

    // Simple execution logic for the MVP
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Executing voice command: ${intent.type.name}")),
      );
    }

    switch (intent.type) {
      case VoiceIntentType.triggerSos:
        _triggerSOS();
        break;
      case VoiceIntentType.fakeCall:
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FakeCallScreen()));
        }
        break;
      case VoiceIntentType.startRecording:
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InstantVideoScreen()));
        }
        break;
      case VoiceIntentType.silentRecord:
        if (!_isRecording) {
          await SilentRecorder.instance.startRecording();
          if (mounted) setState(() => _isRecording = SilentRecorder.instance.isRecording);
        }
        break;
      case VoiceIntentType.startCheckin:
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SoloTripScreen()));
        }
        break;
      default:
        break;
    }
  }

  Future<void> _toggleRecord() async {
    if (_isRecording) {
      final path = await SilentRecorder.instance.stopRecording();
      if (mounted) setState(() => _isRecording = false);
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to: $path')),
        );
      }
    } else {
      await SilentRecorder.instance.startRecording();
      if (mounted) {
        setState(() => _isRecording = SilentRecorder.instance.isRecording);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silent recording started')),
        );
      }
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
      backgroundColor: const Color(0xFF1A0A14),
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable Content
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 115),
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
                        onLongPress: _showVoiceOverlay,
                        onTap: _triggerSOS,
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
                    _buildHelplinesCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            
            // ── Pull-up Dynamic Drawer (5 buttons morph to Legal AI Chat) ──
            Positioned.fill(
              child: _AnimatedBottomDrawer(
                isRecording: _isRecording,
                onFakeCall: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FakeCallScreen())),
                onRecord: _toggleRecord,
                onVoice: _showVoiceOverlay,
                onSoloTrip: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SoloTripScreen())),
                onVideoRec: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InstantVideoScreen())),
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

  Widget _buildHelplinesCard() {
    return _buildCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _helplinesExpanded = !_helplinesExpanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.phone_in_talk, color: Colors.white, size: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Emergency Helplines',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _helplinesExpanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: Colors.white10),
                _buildHelplineRow('National Emergency', '112'),
                _buildHelplineRow('Police', '100'),
                _buildHelplineRow('Women Helpline', '181'),
                _buildHelplineRow('Ambulance', '108'),
                const SizedBox(height: 8),
              ],
            ),
            crossFadeState: _helplinesExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpRow(IconData icon, String title, String distance) {
    return InkWell(
      onTap: () {
        // Open map
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white),
              ),
            ),
            Text(distance, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildHelplineRow(String title, String number) {
    return InkWell(
      onTap: () async {
        final Uri telUrl = Uri.parse('tel:$number');
        if (await canLaunchUrl(telUrl)) {
          await launchUrl(telUrl);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
            Text(
              number, 
              style: GoogleFonts.inter(
                color: OnboardingColors.coral, 
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Pull-up Dynamic Drawer — 5 Action Buttons morph to Legal AI Chat
// ══════════════════════════════════════════════════════════════════════════

class _AnimatedBottomDrawer extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onFakeCall;
  final VoidCallback onRecord;
  final VoidCallback onVoice;
  final VoidCallback onSoloTrip;
  final VoidCallback onVideoRec;

  const _AnimatedBottomDrawer({
    required this.isRecording,
    required this.onFakeCall,
    required this.onRecord,
    required this.onVoice,
    required this.onSoloTrip,
    required this.onVideoRec,
  });

  @override
  State<_AnimatedBottomDrawer> createState() => _AnimatedBottomDrawerState();
}

class _AnimatedBottomDrawerState extends State<_AnimatedBottomDrawer> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _drawerCurve;

  static const double _dockHeight = 92.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _drawerCurve = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _expand() => _animController.forward();
  void _collapse() => _animController.reverse();

  void _handleVerticalDragUpdate(DragUpdateDetails details, double drawerHeight) {
    final delta = details.primaryDelta ?? 0;
    if (drawerHeight > 0) {
      _animController.value -= delta / drawerHeight;
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -250) {
      _animController.forward();
    } else if (velocity > 250) {
      _animController.reverse();
    } else {
      if (_animController.value >= 0.3) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final drawerHeight = screenHeight * 0.88;

    return Stack(
      children: [
        // ── 1. Collapsed Dock: 5 Clean Minimalist Action Buttons ──
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _dockHeight,
          child: AnimatedBuilder(
            animation: _drawerCurve,
            builder: (context, child) {
              final t = _drawerCurve.value;
              return IgnorePointer(
                ignoring: t > 0.15,
                child: Opacity(
                  opacity: (1.0 - (t * 2.0)).clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onVerticalDragUpdate: (details) => _handleVerticalDragUpdate(details, drawerHeight),
              onVerticalDragEnd: _handleVerticalDragEnd,
              behavior: HitTestBehavior.opaque,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF24141D),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle & Hint
                    GestureDetector(
                      onTap: _expand,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 2),
                        child: Column(
                          children: [
                            Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white30,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.keyboard_arrow_up_rounded, color: OnboardingColors.coral, size: 14),
                                const SizedBox(width: 3),
                                Text(
                                  'Swipe up for Legal AI Chat',
                                  style: GoogleFonts.inter(
                                    color: Colors.white60,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 2),

                    // 5 Minimalist, Clean Grayed-Out Action Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildDockButton(
                            Icons.phone_in_talk,
                            'Fake Call',
                            widget.onFakeCall,
                          ),
                          _buildDockButton(
                            widget.isRecording ? Icons.stop : Icons.mic_none,
                            widget.isRecording ? 'Stop' : 'Record',
                            widget.onRecord,
                            isStop: widget.isRecording,
                          ),
                          _buildDockButton(
                            Icons.graphic_eq,
                            'Voice',
                            widget.onVoice,
                          ),
                          _buildDockButton(
                            Icons.route,
                            'Solo Trip',
                            widget.onSoloTrip,
                          ),
                          _buildDockButton(
                            Icons.videocam,
                            'Video',
                            widget.onVideoRec,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── 2. Expanded Legal AI Help Chat (Smooth GPU SlideTransition) ──
        AnimatedBuilder(
          animation: _drawerCurve,
          builder: (context, child) {
            final t = _drawerCurve.value;
            if (t <= 0.001) return const SizedBox.shrink();

            return Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: drawerHeight,
              child: Transform.translate(
                offset: Offset(0, (1.0 - t) * drawerHeight),
                child: child,
              ),
            );
          },
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF24141D),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(26),
                topRight: Radius.circular(26),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black87,
                  blurRadius: 24,
                  spreadRadius: 4,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta != null && details.primaryDelta! > 12) {
                  _collapse();
                }
              },
              child: LegalChatView(
                onClose: _collapse,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDockButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isStop = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isStop ? Colors.redAccent : Colors.white54,
              size: 21,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isStop ? Colors.redAccent : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
