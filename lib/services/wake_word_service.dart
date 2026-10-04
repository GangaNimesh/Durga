import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:open_wake_word/open_wake_word.dart';
import 'package:record/record.dart';

import 'voice_command_service.dart';
import 'supabase_service.dart';

class WakeWordService {
  WakeWordService._();
  static final WakeWordService instance = WakeWordService._();

  final _record = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSub;
  bool _isListening = false;
  bool _isInitializing = false;

  bool get isListening => _isListening;

  Future<void> initAndStart() async {
    if (_isListening || _isInitializing) return;
    _isInitializing = true;

    try {
      // Check if user has always_listening enabled
      final settings = await SupabaseService.instance.getVoiceSettings();
      final alwaysListening = settings?['always_listening'] ?? false;
      if (!alwaysListening) {
        debugPrint("Always-listening is disabled in settings.");
        _isInitializing = false;
        return;
      }

      debugPrint("Initializing OpenWakeWord models...");
      final initSuccess = await OpenWakeWord.init(
        melModelAssetPath: 'assets/wake_word/melspectrogram.onnx',
        embModelAssetPath: 'assets/wake_word/embedding_model.onnx',
        wwModelAssetPaths: ['assets/wake_word/hey_jarvis.onnx'],
      );

      if (!initSuccess) {
        debugPrint("Failed to initialize OpenWakeWord.");
        _isInitializing = false;
        return;
      }

      if (await _record.hasPermission()) {
        final stream = await _record.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ));
        
        _isListening = true;
        debugPrint("Wake word service started. Listening for Hey Jarvis...");

        _audioStreamSub = stream.listen((data) {
          if (!_isListening) return;

          // Convert Uint8List to Int16List for OpenWakeWord
          final int16Data = Int16List.view(data.buffer, data.offsetInBytes, data.lengthInBytes ~/ 2);
          OpenWakeWord.processAudio(int16Data);
          
          if (OpenWakeWord.isActivated()) {
            _wakeWordDetected();
          }
        });
      }
    } catch (e) {
      debugPrint("Wake word init error: $e");
    } finally {
      _isInitializing = false;
    }
  }

  void _wakeWordDetected() {
    debugPrint("Wake word detected via openWakeWord!");
    // Temporarily pause wake word processing
    stop();
    // Fire VoiceCommandOverlay or any intent handling here via global stream/provider in real app
  }

  Future<void> stop() async {
    if (!_isListening) return;
    try {
      _isListening = false;
      await _audioStreamSub?.cancel();
      await _record.stop();
      OpenWakeWord.destroy();
      debugPrint("Wake word service stopped.");
    } catch (e) {
      debugPrint("Error stopping wake word: $e");
    }
  }
}
