import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/colors.dart';
import '../models/app_models.dart';
import '../services/app_service.dart';

class SafezoneScreen extends StatefulWidget {
  const SafezoneScreen({super.key});

  @override
  State<SafezoneScreen> createState() => _SafezoneScreenState();
}

class _SafezoneScreenState extends State<SafezoneScreen> {
  Journey? activeJourney;
  bool isLoading = true;
  bool isBusy = false;
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
      final journey = await AppService.getActiveJourney();
      setState(() => activeJourney = journey);
    } catch (e) {
      setState(() => error = 'Could not load journey status: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<Position?> _currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _start() async {
    setState(() => isBusy = true);
    try {
      final pos = await _currentPosition();
      final journey = await AppService.startJourney(
        startLat: pos?.latitude,
        startLng: pos?.longitude,
      );
      setState(() => activeJourney = journey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journey started — stay safe')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start journey: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<void> _stop() async {
    if (activeJourney == null) return;
    setState(() => isBusy = true);
    try {
      await AppService.stopJourney(activeJourney!.id);
      setState(() => activeJourney = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journey stopped')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not stop journey: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isBusy = false);
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
                "SafeZone — Journey Tracking",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                "Start a journey before you travel so the app can restore your trip status if it's killed in the background.",
                style: TextStyle(color: AppColors.subtitle),
              ),
              const SizedBox(height: 24),

              if (isLoading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ))
              else if (error != null)
                Text(error!, style: const TextStyle(color: Colors.orange))
              else
                _statusCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard() {
    final active = activeJourney != null;

    return Container(
      padding: const EdgeInsets.all(24),
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
              Icon(
                active ? Icons.directions_walk : Icons.pause_circle_outline,
                color: active ? AppColors.lowRisk : Colors.grey,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                active ? "Journey in progress" : "No active journey",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          if (active) ...[
            const SizedBox(height: 16),
            _row('Started', activeJourney!.createdAt.toLocal().toString().split('.').first),
            if (activeJourney!.startLatitude != null)
              _row(
                'Start location',
                '${activeJourney!.startLatitude!.toStringAsFixed(4)}, ${activeJourney!.startLongitude!.toStringAsFixed(4)}',
              ),
          ],

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isBusy ? null : (active ? _stop : _start),
              style: ElevatedButton.styleFrom(
                backgroundColor: active ? Colors.redAccent : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                isBusy ? "Please wait..." : (active ? "Stop Journey" : "Start Journey"),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
