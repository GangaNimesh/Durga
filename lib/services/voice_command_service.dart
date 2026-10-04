import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

import 'voice_intent.dart';
import 'supabase_service.dart';

class VoiceCommandService {
  VoiceCommandService._();
  static final VoiceCommandService instance = VoiceCommandService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = await _speech.initialize(
      onError: (val) => debugPrint('STT Error: $val'),
      onStatus: (val) => debugPrint('STT Status: $val'),
    );
  }

  /// Starts listening for a single voice command (timeout driven by OS usually)
  Future<void> startListening({
    required Function(String transcript) onPartial,
    required Function(VoiceIntent intent) onComplete,
    required VoidCallback onTimeout,
  }) async {
    if (!_isInitialized) await init();
    if (!_isInitialized) {
      debugPrint("STT initialization failed");
      return;
    }

    _isListening = true;
    String lastRecognizedWords = "";
    
    // We listen until the user stops talking or speech_to_text decides it's done.
    await _speech.listen(
      onResult: (result) {
        lastRecognizedWords = result.recognizedWords;
        onPartial(result.recognizedWords);
        
        if (result.finalResult) {
          _isListening = false;
          final intent = _parseIntent(result.recognizedWords);
          onComplete(intent);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
      listenMode: stt.ListenMode.confirmation,
    );

    // Fallback if OS doesn't fire finalResult
    Future.delayed(const Duration(seconds: 11), () {
      if (_isListening) {
        _isListening = false;
        _speech.stop();
        if (lastRecognizedWords.isNotEmpty) {
          final intent = _parseIntent(lastRecognizedWords);
          onComplete(intent);
        } else {
          onTimeout();
        }
      }
    });
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  Future<void> speak(String text) async {
    await _tts.setLanguage("en-IN");
    await _tts.speak(text);
  }

  VoiceIntent _parseIntent(String transcript) {
    final t = transcript.toLowerCase().trim();

    if (t.isEmpty) {
      return VoiceIntent(type: VoiceIntentType.unknown, rawTranscript: transcript);
    }

    // Cancel variants
    if (t.contains("cancel") || t.contains("stop") || t.contains("okay") || t.contains("false alarm") || t.contains("never mind")) {
      return VoiceIntent(type: VoiceIntentType.cancel, rawTranscript: transcript);
    }

    // SOS / Emergency variants
    if (t.contains("trigger sos") || t.contains("help me") || t.contains("emergency") || t.contains("i need help")) {
      return VoiceIntent(type: VoiceIntentType.triggerSos, rawTranscript: transcript);
    }

    // Video Recording
    if (t.contains("start recording") || t.contains("record video") || t.contains("video on")) {
      return VoiceIntent(type: VoiceIntentType.startRecording, rawTranscript: transcript);
    }

    // Audio Recording
    if (t.contains("silent record") || t.contains("record audio") || t.contains("audio recording")) {
      return VoiceIntent(type: VoiceIntentType.silentRecord, rawTranscript: transcript);
    }

    // Fake Call
    if (t.contains("fake call") || t.contains("pretend call")) {
      return VoiceIntent(type: VoiceIntentType.fakeCall, rawTranscript: transcript);
    }

    // Where am I
    if (t.contains("where am i") || t.contains("read my location") || t.contains("what's my location")) {
      return VoiceIntent(type: VoiceIntentType.whereAmI, rawTranscript: transcript);
    }

    // Send location all
    if (t.contains("send location to all") || t.contains("share with everyone")) {
      return VoiceIntent(type: VoiceIntentType.sendLocationAll, rawTranscript: transcript);
    }

    // Share Location specific contact
    if (t.contains("share my location with") || t.contains("send location to")) {
      String name = _extractName(t, ["share my location with", "send location to"]);
      return VoiceIntent(type: VoiceIntentType.shareLocation, contactName: name, rawTranscript: transcript);
    }

    // Call contact
    if (t.contains("call ") || t.contains("phone ") || t.contains("dial ")) {
      String name = _extractName(t, ["call ", "phone ", "dial "]);
      return VoiceIntent(type: VoiceIntentType.callContact, contactName: name, rawTranscript: transcript);
    }

    // Check in
    if (t.contains("start check-in") || t.contains("start check in") || t.contains("solo trip mode")) {
      return VoiceIntent(type: VoiceIntentType.startCheckin, rawTranscript: transcript);
    }

    return VoiceIntent(type: VoiceIntentType.unknown, rawTranscript: transcript);
  }

  String _extractName(String transcript, List<String> prefixes) {
    for (var prefix in prefixes) {
      if (transcript.contains(prefix)) {
        return transcript.split(prefix).last.trim();
      }
    }
    return '';
  }

  Future<void> executeIntent(VoiceIntent intent, BuildContext context) async {
    // We log it right before execution
    await SupabaseService.instance.logVoiceCommand(
      wakeDetected: false, // We'll update this in Phase 1b
      transcript: intent.rawTranscript,
      matchedIntent: intent.type.toString(),
      actionTaken: 'Executed',
      cancelled: false,
    );

    // Depending on intent, trigger actions here or let the UI layer handle routing
    // For MVP, we let UI overlay handle navigation/cancellation logic before calling action
  }
}
