import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';
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
  final String _notifyMethod = 'notification';
  bool _isLoading = false;

  void _startSoloTrip() async {
    setState(() => _isLoading = true);
    try {
      await SoloTripService.instance.startSession(
        intervalMinutes: _intervalMinutes,
        gracePeriodMinutes: _gracePeriodMinutes,
        notifyMethod: _notifyMethod,
        alertContactIds: [],
      );
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solo Trip Started! Ongoing protection is active.'),
            backgroundColor: Colors.teal,
          ),
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
    final locale = Provider.of<LocaleProvider>(context);

    return Scaffold(
      backgroundColor: OnboardingColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          locale.isTelugu ? 'సోలో ట్రిప్ మోడ్' : 'Solo Trip Mode',
          style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 24),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListenableBuilder(
        listenable: SoloTripService.instance,
        builder: (context, _) {
          final isSoloActive = SoloTripService.instance.isActive;
          if (isSoloActive) {
            return _buildActiveTripView(context, locale);
          }
          return _buildSetupTripView(locale);
        },
      ),
    );
  }

  Widget _buildActiveTripView(BuildContext context, LocaleProvider locale) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00E676).withValues(alpha: 0.12),
              border: Border.all(color: const Color(0xFF00E676), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E676).withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.shield, color: Color(0xFF00E676), size: 52),
          ),
          const SizedBox(height: 24),
          Text(
            locale.isTelugu ? 'సోలో ట్రిప్ రన్ అవుతోంది' : 'Solo Trip is Active',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            locale.isTelugu
                ? 'మీ ప్రయాణం నిరంతరం పరిశీలించబడుతోంది. ప్రతి ${SoloTripService.instance.intervalMinutes} నిమిషాలకు చెక్-ఇన్ హెచ్చరిక వస్తుంది.'
                : 'Your journey is protected. Durga will send check-in reminders every ${SoloTripService.instance.intervalMinutes} minutes.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 40),
          
          // I am safe button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () async {
                await SoloTripService.instance.confirmCheckin();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(locale.isTelugu ? 'చెక్-ఇన్ నిర్ధారించబడింది!' : 'Check-in confirmed! Stay safe.'),
                      backgroundColor: Colors.teal,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(
                locale.isTelugu ? 'నేను సురక్షితంగా ఉన్నాను' : 'I am safe (Check-in Now)',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // End solo trip button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () async {
                await SoloTripService.instance.endSession();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(locale.isTelugu ? 'సోలో ట్రిప్ ముగిసింది.' : 'Solo Trip ended successfully.'),
                      backgroundColor: OnboardingColors.coral,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
              label: Text(
                locale.isTelugu ? 'ట్రిప్ ముగించు' : 'End Solo Trip',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupTripView(LocaleProvider locale) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            locale.isTelugu
                ? 'ఆవర్తన చెక్-ఇన్‌లను సెటప్ చేయండి. నిర్దేశిత సమయంలో మీరు స్పందించకపోతే మీ లైవ్ లొకేషన్‌తో ఎమర్జెన్సీ పరిచయాలు అప్రమత్తమవుతాయి.'
                : 'Set up periodic check-ins. If you fail to check in before the grace period ends, your emergency contacts will be alerted with your live location.',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          
          Text(
            locale.isTelugu ? 'చెక్-ఇన్ విరామం' : 'Check-in Interval',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _intervalMinutes.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            activeColor: OnboardingColors.coral,
            label: '$_intervalMinutes min',
            onChanged: (val) => setState(() => _intervalMinutes = val.toInt()),
          ),
          Text(
            locale.isTelugu ? 'ప్రతి $_intervalMinutes నిమిషాలకు' : 'Every $_intervalMinutes minutes',
            style: GoogleFonts.inter(color: OnboardingColors.coral, fontSize: 14),
          ),
          
          const SizedBox(height: 32),
          Text(
            locale.isTelugu ? 'గ్రేస్ పీరియడ్' : 'Grace Period',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _gracePeriodMinutes.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: OnboardingColors.coral,
            label: '$_gracePeriodMinutes min',
            onChanged: (val) => setState(() => _gracePeriodMinutes = val.toInt()),
          ),
          Text(
            locale.isTelugu
                ? 'అలర్ట్ పంపే ముందు $_gracePeriodMinutes నిమిషాలు'
                : '$_gracePeriodMinutes minutes before alert is sent',
            style: GoogleFonts.inter(color: OnboardingColors.coral, fontSize: 14),
          ),
          
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
                      locale.isTelugu ? 'సోలో ట్రిప్ ప్రారంభించండి' : 'Start Solo Trip',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
