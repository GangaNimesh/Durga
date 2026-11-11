import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_file/open_file.dart';

import '../services/supabase_service.dart';
import '../services/solo_trip_service.dart';
import '../services/safety_notification_service.dart';
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
  List<FileSystemEntity> _recordings = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadRecordings();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await SupabaseService.instance.getUser();
      Map<String, dynamic>? voiceSettings;
      try {
        voiceSettings = await SupabaseService.instance.getVoiceSettings();
      } catch (e) {
        debugPrint('Could not load voice settings: $e');
      }
      if (mounted) {
        setState(() {
          _userData = user;
          _alwaysListening = voiceSettings?['always_listening'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRecordings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final allFiles = dir.listSync();
      final recordings = allFiles.where((f) {
        if (f is! File) return false;
        final name = f.path.split(Platform.pathSeparator).last.toLowerCase();
        return name.startsWith('durga_record') && name.endsWith('.m4a');
      }).toList();

      // Also check for video recordings from camera (in cache/temp dirs)
      final cacheDir = await getTemporaryDirectory();
      final cacheDirFiles = cacheDir.listSync(recursive: true);
      final videoRecordings = cacheDirFiles.where((f) {
        if (f is! File) return false;
        final name = f.path.split(Platform.pathSeparator).last.toLowerCase();
        return name.endsWith('.mp4');
      }).toList();

      recordings.addAll(videoRecordings);

      // Sort by last modified, newest first
      recordings.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      if (mounted) {
        setState(() => _recordings = recordings);
      }
    } catch (e) {
      debugPrint('Error loading recordings: $e');
    }
  }

  Future<void> _deleteRecording(FileSystemEntity file) async {
    try {
      await file.delete();
      _loadRecordings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording deleted'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      debugPrint('Error deleting recording: $e');
    }
  }

  Future<void> _shareRecording(File file) async {
    try {
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      debugPrint('Error sharing recording: $e');
    }
  }

  Future<void> _openRecording(File file) async {
    try {
      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint('Error opening recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open this file'), backgroundColor: Colors.redAccent),
        );
      }
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

                const SizedBox(height: 32),

                // Widgets & Lock Screen Section
                Text(
                  'WIDGETS & LOCK SCREEN',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lock Screen Safety Widget',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Persistent SOS, Fake Call, Record & Voice controls visible on lock screen',
                                  style: GoogleFonts.inter(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: SafetyNotificationService.instance.isEnabled,
                            onChanged: (val) async {
                              await SafetyNotificationService.instance.setEnabled(val);
                              setState(() {});
                            },
                            activeThumbColor: OnboardingColors.coral,
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.widgets_outlined, color: OnboardingColors.coral, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Home Screen Widget: Long-press your home screen → Widgets → select "Durga Pocket Guard" to add the 4x2 quick-action bar.',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Recordings Section
                Text(
                  'RECORDINGS',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRecordingsSection(),
                const SizedBox(height: 32),

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

  Widget _buildRecordingsSection() {
    if (_recordings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            const Icon(Icons.folder_open, color: Colors.white24, size: 40),
            const SizedBox(height: 12),
            Text(
              'No recordings yet',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Use the Record or Video buttons to create recordings',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.library_music, color: OnboardingColors.coral, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_recordings.length} Recording${_recordings.length == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _recordings.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final file = _recordings[index] as File;
              final fileName = file.path.split(Platform.pathSeparator).last;
              final stat = file.statSync();
              final sizeKb = (stat.size / 1024).toStringAsFixed(1);
              final sizeMb = (stat.size / (1024 * 1024)).toStringAsFixed(1);
              final sizeText = stat.size > 1024 * 1024 ? '$sizeMb MB' : '$sizeKb KB';
              final date = stat.modified;
              final dateStr = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';

              final isVideo = fileName.toLowerCase().endsWith('.mp4');
              final isAudio = fileName.toLowerCase().endsWith('.m4a');

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Type icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isVideo ? Colors.deepPurple : Colors.teal).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isVideo ? Icons.videocam : Icons.mic,
                        color: isVideo ? Colors.deepPurple.shade200 : Colors.tealAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // File info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              // Type badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isVideo ? Colors.deepPurple : Colors.teal).withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isVideo ? 'VIDEO' : (isAudio ? 'AUDIO' : 'FILE'),
                                  style: GoogleFonts.inter(
                                    color: isVideo ? Colors.deepPurple.shade200 : Colors.tealAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$sizeText • $dateStr',
                                style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Action buttons
                    IconButton(
                      icon: const Icon(Icons.play_arrow, color: Colors.white54, size: 20),
                      onPressed: () => _openRecording(file),
                      tooltip: 'Open',
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white54, size: 18),
                      onPressed: () => _shareRecording(file),
                      tooltip: 'Share',
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF2A1A24),
                            title: Text('Delete Recording?', style: GoogleFonts.inter(color: Colors.white)),
                            content: Text(
                              'This will permanently delete "$fileName".',
                              style: GoogleFonts.inter(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _deleteRecording(file);
                                },
                                child: Text('Delete', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      },
                      tooltip: 'Delete',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              );
            },
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
