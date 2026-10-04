import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/voice_intent.dart';
import '../../services/voice_command_service.dart';
import '../../theme/onboarding_colors.dart';

class VoiceCommandOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final Function(VoiceIntent) onIntentConfirmed;

  const VoiceCommandOverlay({
    super.key,
    required this.onDismiss,
    required this.onIntentConfirmed,
  });

  @override
  State<VoiceCommandOverlay> createState() => _VoiceCommandOverlayState();
}

class _VoiceCommandOverlayState extends State<VoiceCommandOverlay> with SingleTickerProviderStateMixin {
  String _transcript = "Listening...";
  VoiceIntent? _detectedIntent;
  bool _isProcessing = false;
  bool _isCountdown = false;
  int _countdown = 3;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _startListening();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    VoiceCommandService.instance.stopListening();
    super.dispose();
  }

  void _startListening() {
    VoiceCommandService.instance.startListening(
      onPartial: (transcript) {
        if (mounted) setState(() => _transcript = transcript);
      },
      onComplete: (intent) {
        if (mounted) {
          setState(() {
            _detectedIntent = intent;
            _isProcessing = true;
          });
          _handleIntent(intent);
        }
      },
      onTimeout: () {
        if (mounted) {
          setState(() {
            _transcript = "Didn't catch that.";
            _isProcessing = false;
          });
          Future.delayed(const Duration(seconds: 2), widget.onDismiss);
        }
      },
    );
  }

  void _handleIntent(VoiceIntent intent) {
    if (intent.type == VoiceIntentType.cancel) {
      widget.onDismiss();
      return;
    }

    if (intent.type == VoiceIntentType.unknown) {
      setState(() {
        _transcript = "Command not recognized";
      });
      Future.delayed(const Duration(seconds: 2), widget.onDismiss);
      return;
    }

    // Start 3 second countdown for destructive actions
    if (_isDestructive(intent.type)) {
      setState(() {
        _isCountdown = true;
      });
      _runCountdown();
    } else {
      widget.onIntentConfirmed(intent);
    }
  }

  bool _isDestructive(VoiceIntentType type) {
    return type == VoiceIntentType.triggerSos || 
           type == VoiceIntentType.callContact || 
           type == VoiceIntentType.shareLocation || 
           type == VoiceIntentType.sendLocationAll;
  }

  void _runCountdown() async {
    while (_countdown > 0 && mounted && _isCountdown) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _isCountdown) {
        setState(() => _countdown--);
      }
    }
    
    if (_countdown == 0 && mounted && _isCountdown) {
      widget.onIntentConfirmed(_detectedIntent!);
    }
  }

  void _cancelCommand() {
    setState(() => _isCountdown = false);
    VoiceCommandService.instance.stopListening();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.85),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            
            // Microphone Pulse
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 120 + (_pulseController.value * 20),
                  height: 120 + (_pulseController.value * 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCountdown 
                        ? Colors.red.withOpacity(0.3)
                        : OnboardingColors.coral.withOpacity(0.3),
                  ),
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isCountdown ? Colors.red : OnboardingColors.coral,
                      ),
                      child: const Icon(Icons.mic, color: Colors.white, size: 40),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 40),
            
            // Transcript
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _isCountdown 
                    ? "Action: ${_detectedIntent?.type.name}" 
                    : _transcript,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            if (_isCountdown) ...[
              const SizedBox(height: 20),
              Text(
                "Executing in $_countdown...",
                style: GoogleFonts.inter(
                  color: Colors.redAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            
            const Spacer(),
            
            // Cancel Button
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: ElevatedButton.icon(
                onPressed: _cancelCommand,
                icon: const Icon(Icons.close, color: Colors.white),
                label: Text(
                  "Cancel",
                  style: GoogleFonts.inter(fontSize: 18, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
