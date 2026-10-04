import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/onboarding_colors.dart';

class InstantVideoScreen extends StatefulWidget {
  const InstantVideoScreen({super.key});

  @override
  State<InstantVideoScreen> createState() => _InstantVideoScreenState();
}

class _InstantVideoScreenState extends State<InstantVideoScreen> {
  CameraController? _controller;
  bool _isRecording = false;
  bool _isInitializing = true;
  String _errorMsg = '';
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    _initCameraAndRecord();
  }

  Future<void> _initCameraAndRecord() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMsg = 'No cameras found on device.';
          _isInitializing = false;
        });
        return;
      }

      // Default to back camera
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _controller!.initialize();

      if (!mounted) return;

      setState(() {
        _isInitializing = false;
      });

      // Instantly start recording!
      await _startRecording();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Error initializing camera: $e';
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isRecordingVideo) return;

    try {
      await _controller!.startVideoRecording();
      if (mounted) {
        setState(() => _isRecording = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = 'Failed to start recording: $e');
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) return;

    try {
      final xFile = await _controller!.stopVideoRecording();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _videoPath = xFile.path;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video saved to: ${_videoPath}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = 'Failed to stop recording: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: OnboardingColors.coral)),
      );
    }

    if (_errorMsg.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _errorMsg,
              style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          if (_controller != null && _controller!.value.isInitialized)
            CameraPreview(_controller!),

          // Safe Area overlays
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 32),
                        onPressed: () {
                          if (_isRecording) {
                            _stopRecording();
                          }
                          Navigator.pop(context);
                        },
                      ),
                      if (_isRecording)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'REC',
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom Controls
                Padding(
                  padding: const EdgeInsets.only(bottom: 40.0),
                  child: GestureDetector(
                    onTap: () {
                      if (_isRecording) {
                        _stopRecording();
                      } else {
                        _startRecording();
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _isRecording ? 32 : 64,
                          height: _isRecording ? 32 : 64,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(_isRecording ? 8 : 32),
                          ),
                        ),
                      ),
                    ),
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
