import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/colors.dart';
import '../services/app_service.dart';
import '../widgets/common/header_widget.dart';
import '../widgets/cards/sos_card.dart';
import '../widgets/cards/contacts_card.dart';
import '../widgets/cards/threat_card.dart';
import '../widgets/cards/location_card.dart';
import '../widgets/cards/evidence_card.dart';
import '../widgets/buttons/emergency_button.dart';
import '../widgets/buttons/copy_sos_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? _position;
  bool _isSendingSOS = false;
  String? _lastSOSMessage;

  Future<void> _sendSOS() async {
    if (_isSendingSOS) return;

    setState(() {
      _isSendingSOS = true;
    });

    try {
      final alert = await AppService.triggerSOS(
        _position?.latitude,
        _position?.longitude,
      );

      final coords = _position != null
          ? '${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}'
          : 'unavailable';
      final mapsLink = _position != null
          ? 'https://maps.google.com/?q=${_position!.latitude},${_position!.longitude}'
          : '';

      setState(() {
        _lastSOSMessage =
            '🚨 EMERGENCY!\nI need immediate help.\nTriggered: ${alert.createdAt.toLocal()}\n'
            'Coordinates: $coords\n$mapsLink';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 SOS alert sent to the server'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send SOS: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingSOS = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HeaderWidget(),

              SosCard(
                isSending: _isSendingSOS,
                onPressed: _sendSOS,
              ),

              const ContactsCard(),

              const ThreatCard(),

              LocationCard(
                onLocationChanged: (pos) {
                  setState(() {
                    _position = pos;
                  });
                },
              ),

              const EvidenceCard(),

              const EmergencyButton(),

              const SizedBox(height: 15),

              CopySOSButton(message: _lastSOSMessage),

              const SizedBox(height: 25),

              const Text(
                "ANDHRA PRADESH REGIONAL MVP V1.2",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}
