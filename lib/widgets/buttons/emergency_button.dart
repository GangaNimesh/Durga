import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/colors.dart';
import '../../models/app_models.dart';
import '../../services/app_service.dart';

class EmergencyButton extends StatefulWidget {
  const EmergencyButton({super.key});

  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton> {
  List<Helpline> helplines = [];
  bool isLoading = true;

  // Shown until the backend list loads, and as a fallback if it fails —
  // these two numbers should always be reachable.
  static const _fallback = [
    Helpline(id: '', name: 'National Emergency Number', phone: '112', category: 'General Emergency'),
    Helpline(id: '', name: "Women's Safety Helpline", phone: '181', category: 'Women Safety'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await AppService.getHelplines();
      if (mounted) {
        setState(() {
          helplines = result.take(4).toList();
        });
      }
    } catch (_) {
      // Fall back to the hardcoded list below — dialing 112/181 must never
      // depend on the backend being reachable.
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> callNumber(String number) async {
    final Uri uri = Uri(scheme: "tel", path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget buildButton(Helpline helpline) {
    return InkWell(
      onTap: () => callNumber(helpline.phone),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.maroon,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.call, color: AppColors.maroon),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dial ${helpline.phone} — ${helpline.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    helpline.category ?? '',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = helplines.isNotEmpty ? helplines : _fallback;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: list.map(buildButton).toList(),
      ),
    );
  }
}
