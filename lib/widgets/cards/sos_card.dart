import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class SosCard extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isSending;

  const SosCard({
    super.key,
    required this.onPressed,
    this.isSending = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSending ? null : onPressed,

      child: Container(
        height: 210,

        margin: const EdgeInsets.all(20),

        decoration: BoxDecoration(
          color: isSending ? AppColors.sosRed.withValues(alpha: 0.7) : AppColors.sosRed,
          borderRadius: BorderRadius.circular(32),
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.sosRed,
                      ),
                    )
                  : const Icon(
                      Icons.priority_high,
                      color: AppColors.sosRed,
                      size: 34,
                    ),
            ),

            const SizedBox(height: 18),

            Text(
              isSending ? "SENDING SOS..." : "SEND SOS ALERT",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Instant alert to all trusted contacts",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
