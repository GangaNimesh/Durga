import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/colors.dart';
import '../../models/app_models.dart';
import '../../services/app_service.dart';

class EvidenceCard extends StatefulWidget {
  const EvidenceCard({super.key});

  @override
  State<EvidenceCard> createState() => _EvidenceCardState();
}

class _EvidenceCardState extends State<EvidenceCard> {
  final ImagePicker picker = ImagePicker();

  List<Evidence> evidence = [];
  bool isLoading = true;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final result = await AppService.listEvidence();
      setState(() => evidence = result);
    } catch (_) {
      // Non-fatal — the upload buttons still work even if listing fails.
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _upload(XFile? file) async {
    if (file == null) return;

    setState(() => isUploading = true);
    try {
      await AppService.uploadEvidence(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evidence uploaded')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Future<void> openCamera() async {
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    await _upload(file);
  }

  Future<void> openVideo() async {
    final file = await picker.pickVideo(source: ImageSource.camera);
    await _upload(file);
  }

  Future<void> _delete(Evidence item) async {
    try {
      await AppService.deleteEvidence(item.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(blurRadius: 8, color: Colors.black12, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_special, color: AppColors.navy),
              const SizedBox(width: 10),
              const Text(
                "Evidence Collection",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  '${evidence.length} saved',
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
            ],
          ),

          const SizedBox(height: 25),

          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: isUploading ? null : openCamera,
                  child: _card(Icons.photo_camera, "Photo\nEvidence"),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: GestureDetector(
                  onTap: isUploading ? null : openVideo,
                  child: _card(Icons.videocam, "Video\nEvidence"),
                ),
              ),
            ],
          ),

          if (isUploading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),

          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text("Uploaded", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...evidence.map(
              (e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xffF4F6FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      e.fileType.startsWith('video') ? Icons.videocam : Icons.image,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${e.fileType} • ${e.createdAt.toLocal()}'.split('.').first,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _delete(e),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(IconData icon, String text) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 46),
          const SizedBox(height: 20),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
