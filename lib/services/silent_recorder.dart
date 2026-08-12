import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class SilentRecorder {
  SilentRecorder._();
  static final SilentRecorder instance = SilentRecorder._();

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/durga_record_$timestamp.m4a';

      await _audioRecorder.start(const RecordConfig(), path: path);
      _isRecording = true;
    }
  }

  Future<String?> stopRecording() async {
    final path = await _audioRecorder.stop();
    _isRecording = false;
    return path;
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}
