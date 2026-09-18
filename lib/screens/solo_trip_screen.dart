import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/onboarding_colors.dart';
import '../services/solo_trip_service.dart';

class SoloTripScreen extends StatefulWidget {
  const SoloTripScreen({super.key});

  @override
  State<SoloTripScreen> createState() => _SoloTripScreenState();
}

class _SoloTripScreenState extends State<SoloTripScreen> {
  int _intervalMinutes = 15;
  int _gracePeriodMinutes = 2;
  String _notifyMethod = 'notification';
  bool _isLoading = false;

  void _startSoloTrip() async {
    setState(() => _isLoading = true);
    try {
      await SoloTripService.instance.startSession(
        intervalMinutes: _intervalMinutes,
        gracePeriodMinutes: _gracePeriodMinutes,
        notifyMethod: _notifyMethod,
        alertContactIds: [], // We'll grab from Supabase default contacts for now
      );
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solo Trip Mode Started!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Solo Trip Mode',
          style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 24),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set up periodic check-ins. If you fail to check in before the grace period ends, your emergency contacts will be alerted with your live location.',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            
            Text('Check-in Interval', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            Slider(
              value: _intervalMinutes.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              activeColor: OnboardingColors.coral,
              label: '$_intervalMinutes min',
              onChanged: (val) => setState(() => _intervalMinutes = val.toInt()),
            ),
            Text('Every $_intervalMinutes minutes', style: GoogleFonts.inter(color: OnboardingColors.coral, fontSize: 14)),
            
            const SizedBox(height: 32),
            Text('Grace Period', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            Slider(
              value: _gracePeriodMinutes.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: OnboardingColors.coral,
              label: '$_gracePeriodMinutes min',
              onChanged: (val) => setState(() => _gracePeriodMinutes = val.toInt()),
            ),
            Text('$_gracePeriodMinutes minutes before alert is sent', style: GoogleFonts.inter(color: OnboardingColors.coral, fontSize: 14)),
            
            const SizedBox(height: 48),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startSoloTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: OnboardingColors.coral,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Start Solo Trip',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
