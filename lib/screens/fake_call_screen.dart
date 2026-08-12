import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  // We can add vibration logic here using vibration package if needed,
  // but for MVP, we just show the UI.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(
              'Mom',
              style: GoogleFonts.inter(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Mobile',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  label: 'Decline',
                  onTap: () => Navigator.of(context).pop(),
                ),
                _buildActionButton(
                  icon: Icons.call,
                  color: Colors.green,
                  label: 'Accept',
                  onTap: () => Navigator.of(context).pop(), // Just dismiss for now
                ),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }
}
