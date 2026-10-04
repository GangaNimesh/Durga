import 'package:flutter/material.dart';
import '../widgets/chat/legal_chat_view.dart';

class LegalChatScreen extends StatelessWidget {
  const LegalChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A14),
      body: SafeArea(
        child: LegalChatView(
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
