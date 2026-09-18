import 'package:flutter/foundation.dart';

enum VoiceIntentType {
  startRecording,
  silentRecord,
  shareLocation,
  callContact,
  triggerSos,
  fakeCall,
  cancel,
  whereAmI,
  sendLocationAll,
  startCheckin,
  unknown
}

class VoiceIntent {
  final VoiceIntentType type;
  final String? contactName;
  final String rawTranscript;

  const VoiceIntent({
    required this.type,
    this.contactName,
    required this.rawTranscript,
  });

  @override
  String toString() {
    return 'VoiceIntent(type: $type, contactName: $contactName, rawTranscript: $rawTranscript)';
  }
}
