import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../services/app_service.dart';

class ThreatCard extends StatefulWidget {
  const ThreatCard({super.key});

  @override
  State<ThreatCard> createState() => _ThreatCardState();
}

class _ThreatCardState extends State<ThreatCard> {
  final TextEditingController controller = TextEditingController();

  String risk = "Low Risk";
  Color riskColor = Colors.green;

  bool isLoading = false;

  Future<void> analyzeThreat() async {
    String text = controller.text;
    if (text.isEmpty) {
      setState(() {
        risk = "Low Risk";
        riskColor = Colors.green;
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await AppService.analyzeThreat(text);
      setState(() {
        risk = response.riskLevel;
        if (response.color == 'red') riskColor = Colors.red;
        else if (response.color == 'orange') riskColor = Colors.orange;
        else riskColor = Colors.green;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to analyze threat: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
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
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.psychology_alt,
                color: AppColors.navy,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Threat Analysis",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  "AI ENGINE",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
              "Describe situation or type keywords like\n'Help', 'Threat', 'Followed'",
              filled: true,
              fillColor: const Color(0xffF5F7FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: isLoading ? null : analyzeThreat,
              icon: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
              label: Text(
                isLoading ? "Analyzing..." : "Analyze Threat Pattern",
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
          ),

          const SizedBox(height: 25),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xffF6F8FC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text(
                  "Current Risk Score:",
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                Text(
                  risk,
                  style: TextStyle(
                    color: riskColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
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