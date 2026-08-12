import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../screens/home_screen.dart';
import '../../screens/safety_screen.dart';
import '../../screens/safezone_screen.dart';
import '../../screens/settings_screen.dart';
import '../../services/app_service.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {

  int currentIndex = 0;
  bool _sendingSOS = false;

  final List<Widget> pages = const [
    HomeScreen(),
    SafetyScreen(),
    SafezoneScreen(),
    SettingsScreen(),
  ];

  Future<void> _quickSOS() async {
    if (_sendingSOS) return;
    setState(() => _sendingSOS = true);

    double? lat;
    double? lng;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {
      // Best-effort: send the alert without coordinates rather than blocking on GPS.
    }

    try {
      await AppService.triggerSOS(lat, lng);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🚨 SOS Activated — alert sent"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send SOS: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingSOS = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: pages[currentIndex],

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xffC81E1E),
        elevation: 10,
        shape: const CircleBorder(),
        onPressed: _sendingSOS ? null : _quickSOS,

        child: _sendingSOS
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.campaign,
                color: Colors.white,
                size: 34,
              ),
      ),

      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        height: 80,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,

        child: Row(

          mainAxisAlignment: MainAxisAlignment.spaceAround,

          children: [

            navItem(
              Icons.home_filled,
              "Home",
              0,
            ),

            navItem(
              Icons.shield_outlined,
              "Safety",
              1,
            ),

            const SizedBox(width: 45),

            navItem(
              Icons.map_outlined,
              "SafeZone",
              2,
            ),

            navItem(
              Icons.settings_outlined,
              "Settings",
              3,
            ),

          ],
        ),
      ),
    );
  }

  Widget navItem(
      IconData icon,
      String text,
      int index,
      ) {

    bool selected = currentIndex == index;

    return InkWell(

      onTap: () {

        setState(() {

          currentIndex = index;

        });

      },

      child: Column(

        mainAxisSize: MainAxisSize.min,

        children: [

          Icon(
            icon,
            color: selected
                ? const Color(0xff315E54)
                : Colors.grey,
          ),

          const SizedBox(height: 4),

          Text(
            text,
            style: TextStyle(
              color: selected
                  ? const Color(0xff315E54)
                  : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),

        ],
      ),
    );
  }
}