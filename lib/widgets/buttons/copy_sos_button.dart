import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopySOSButton extends StatelessWidget {
  final String? message;

  const CopySOSButton({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final hasMessage = message != null;

    return Center(
      child: TextButton.icon(
        onPressed: !hasMessage
            ? null
            : () {
                Clipboard.setData(ClipboardData(text: message!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("SOS message copied")),
                );
              },

        icon: Icon(
          Icons.copy_outlined,
          color: hasMessage ? const Color(0xff394867) : Colors.grey,
        ),

        label: Text(
          hasMessage ? "Copy Last SOS Message" : "No SOS sent yet",
          style: TextStyle(
            color: hasMessage ? const Color(0xff394867) : Colors.grey,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
