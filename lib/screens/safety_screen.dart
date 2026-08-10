import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../models/app_models.dart';
import '../services/app_service.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  List<Helpline> helplines = [];
  List<SOSAlert> history = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        AppService.getHelplines(),
        AppService.getSOSHistory(limit: 20),
      ]);
      setState(() {
        helplines = results[0] as List<Helpline>;
        history = results[1] as List<SOSAlert>;
      });
    } catch (e) {
      setState(() => error = 'Could not load: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _resolve(SOSAlert alert) async {
    try {
      await AppService.resolveSOS(alert.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not resolve alert: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                "Safety",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              if (isLoading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ))
              else if (error != null)
                Text(error!, style: const TextStyle(color: Colors.orange))
              else ...[
                _sectionCard(
                  title: "SOS History",
                  icon: Icons.history,
                  child: history.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No SOS alerts yet.', style: TextStyle(color: Colors.grey)),
                        )
                      : Column(
                          children: history.map((alert) => _alertTile(alert)).toList(),
                        ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: "Emergency Helplines",
                  icon: Icons.local_phone,
                  child: helplines.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No helplines available.', style: TextStyle(color: Colors.grey)),
                        )
                      : Column(
                          children: helplines
                              .map((h) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.call, color: AppColors.maroon),
                                    title: Text(h.name),
                                    subtitle: Text(h.category ?? ''),
                                    trailing: Text(
                                      h.phone,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ))
                              .toList(),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _alertTile(SOSAlert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: alert.isActive ? Colors.red.shade50 : const Color(0xffF4F6FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            alert.isActive ? Icons.warning_amber : Icons.check_circle_outline,
            color: alert.isActive ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.createdAt.toLocal().toString().split('.').first,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  alert.isActive ? 'Active' : 'Resolved',
                  style: TextStyle(color: alert.isActive ? Colors.red : Colors.grey),
                ),
              ],
            ),
          ),
          if (alert.isActive)
            TextButton(
              onPressed: () => _resolve(alert),
              child: const Text('Resolve'),
            ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.navy),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
