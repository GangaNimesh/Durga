import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/onboarding_colors.dart';
import '../../services/supabase_service.dart';

class VoiceLogScreen extends StatefulWidget {
  const VoiceLogScreen({super.key});

  @override
  State<VoiceLogScreen> createState() => _VoiceLogScreenState();
}

class _VoiceLogScreenState extends State<VoiceLogScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await SupabaseService.instance.getVoiceCommandLog();
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
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
          'Voice Activity Log',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: OnboardingColors.coral))
          : _logs.isEmpty 
              ? Center(
                  child: Text(
                    'No voice commands logged yet.',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _logs.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final date = DateTime.parse(log['created_at']).toLocal();
                    final formattedDate = "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '"${log['transcript']}"',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Intent: ${log['matched_intent']}', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                            Text('Action: ${log['action_taken']}', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                            if (log['cancelled'] == true)
                               Text('Status: Cancelled by user', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
                          ],
                        ),
                      ),
                      trailing: Text(
                        formattedDate,
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                      ),
                    );
                  },
                ),
    );
  }
}
