import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'voice_intent.dart';
import 'supabase_service.dart';

class VoiceCommandService {
  VoiceCommandService._();
  static final VoiceCommandService instance = VoiceCommandService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  bool _isInitialized = false;
  bool _isListening = false;
  VoidCallback? _onTimeoutCallback;
  Function(VoiceIntent intent)? _onCompleteCallback;
  String _lastRecognizedWords = "";
  String? _currentLocaleId;

  bool get isListening => _isListening;

  Future<void> init({bool force = false}) async {
    if (_isInitialized && !force) return;

    // Explicitly ensure microphone permission is granted
    final mic = await Permission.microphone.status;
    if (!mic.isGranted) {
      final res = await Permission.microphone.request();
      if (!res.isGranted) {
        debugPrint("[STT] Microphone permission denied");
        _isInitialized = false;
        return;
      }
    }

    try {
      _isInitialized = await _speech.initialize(
        debugLogging: true,
        onError: (val) {
          debugPrint('STT Error: ${val.errorMsg}, permanent: ${val.permanent}');
          if (_isListening) {
            _isListening = false;
            _speech.stop();
            if (_lastRecognizedWords.trim().isNotEmpty) {
              final intent = _parseIntent(_lastRecognizedWords);
              _onCompleteCallback?.call(intent);
            } else {
              _onTimeoutCallback?.call();
            }
          }
          if (val.permanent) {
            _isInitialized = false;
          }
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'done' || status == 'notListening') {
            if (_isListening) {
              _isListening = false;
              if (_lastRecognizedWords.trim().isNotEmpty) {
                final intent = _parseIntent(_lastRecognizedWords);
                _onCompleteCallback?.call(intent);
              } else {
                _onTimeoutCallback?.call();
              }
            }
          }
        },
      );

      final systemLocale = await _speech.systemLocale();
      _currentLocaleId = systemLocale?.localeId ?? 'en_IN';
      debugPrint("[STT] Initialized: $_isInitialized, locale: $_currentLocaleId");
    } catch (e) {
      debugPrint("STT initialize exception: $e");
      _isInitialized = false;
    }
  }

  /// Starts listening for a single voice command
  Future<void> startListening({
    required Function(String transcript) onPartial,
    required Function(VoiceIntent intent) onComplete,
    required VoidCallback onTimeout,
  }) async {
    _lastRecognizedWords = "";
    _onCompleteCallback = onComplete;
    _onTimeoutCallback = onTimeout;

    if (!_isInitialized) await init();
    if (!_isInitialized) {
      debugPrint("STT initialization failed, attempting force re-init");
      await init(force: true);
      if (!_isInitialized) {
        onTimeout();
        return;
      }
    }

    _isListening = true;

    try {
      await _speech.listen(
        onResult: (result) {
          _lastRecognizedWords = result.recognizedWords;
          onPartial(result.recognizedWords);
          
          if (result.finalResult) {
            _isListening = false;
            final intent = _parseIntent(result.recognizedWords);
            onComplete(intent);
          }
        },
        localeId: _currentLocaleId,
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (e) {
      debugPrint("STT listen exception: $e");
      _isListening = false;
      onTimeout();
    }

    // Fallback if OS doesn't fire finalResult
    Future.delayed(const Duration(seconds: 10), () {
      if (_isListening) {
        _isListening = false;
        _speech.stop();
        if (_lastRecognizedWords.trim().isNotEmpty) {
          final intent = _parseIntent(_lastRecognizedWords);
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
    if (t.contains("trigger sos") || t.contains("help me") || t.contains("emergency") || t.contains("i need help") || t.contains("sos") || t.contains("save me") || t.contains("danger")) {
      return VoiceIntent(type: VoiceIntentType.triggerSos, rawTranscript: transcript);
    }

    // Video Recording
    if (t.contains("start recording") || t.contains("record video") || t.contains("video on") || t.contains("camera") || t.contains("film")) {
      return VoiceIntent(type: VoiceIntentType.startRecording, rawTranscript: transcript);
    }

    // Audio Recording
    if (t.contains("silent record") || t.contains("record audio") || t.contains("audio recording") || t.contains("voice memo") || t.contains("silent")) {
      return VoiceIntent(type: VoiceIntentType.silentRecord, rawTranscript: transcript);
    }

    // Fake Call
    if (t.contains("fake call") || t.contains("pretend call") || t.contains("call me") || t.contains("ring me") || t.contains("phone call")) {
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

    // Check in / Solo trip
    if (t.contains("start check-in") || t.contains("start check in") || t.contains("solo trip mode") || t.contains("check in") || t.contains("trip") || t.contains("solo") || t.contains("track me")) {
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
    await SupabaseService.instance.logVoiceCommand(
      wakeDetected: false,
      transcript: intent.rawTranscript,
      matchedIntent: intent.type.toString(),
      actionTaken: 'Executed',
      cancelled: false,
    );
  }
}
