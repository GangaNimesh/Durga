import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import '../../services/supabase_service.dart';
import '../../theme/onboarding_colors.dart';
import '../../screens/contact_picker_screen.dart';

class ManageContactsSheet extends StatefulWidget {
  const ManageContactsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ManageContactsSheet(),
    );
  }

  @override
  State<ManageContactsSheet> createState() => _ManageContactsSheetState();
}

class _ManageContactsSheetState extends State<ManageContactsSheet> {
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final contacts = await SupabaseService.instance.getEmergencyContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addContact() async {
    final picked = await Navigator.of(context).push<fc.Contact>(
      MaterialPageRoute(builder: (_) => const ContactPickerScreen()),
    );
    if (picked != null && picked.phones.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.instance.addEmergencyContact(
          name: picked.displayName,
          phone: picked.phones.first.number,
        );
        await _loadContacts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add contact: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _deleteContact(String id) async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.instance.removeEmergencyContact(id);
      await _loadContacts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete contact: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleActive(String id, bool isActive) async {
    final activeCount = _contacts.where((c) => c['is_active'] == true).length;
    if (!isActive && activeCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 active contacts allowed.')),
      );
      return;
    }

    setState(() {
      final idx = _contacts.indexWhere((c) => c['id'] == id);
      if (idx != -1) {
        _contacts[idx]['is_active'] = !isActive;
      }
    });

    try {
      await SupabaseService.instance.toggleContactActive(id, !isActive);
      await _loadContacts(); // reload to ensure consistency
    } catch (e) {
      // Revert on error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update contact: $e')),
        );
        _loadContacts(); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF1A0A14), // Dark plum
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trusted Contacts',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Add up to 3 active contacts to display on your homepage and notify in emergencies.',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Contacts List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: OnboardingColors.coral))
                : _contacts.isEmpty
                    ? Center(
                        child: Text(
                          'No contacts added yet.',
                          style: GoogleFonts.inter(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final contact = _contacts[index];
                          final id = contact['id'] as String;
                          final name = contact['name'] as String;
                          final phone = contact['phone'] as String;
                          final isActive = contact['is_active'] as bool;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isActive ? OnboardingColors.coral : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: isActive ? OnboardingColors.coral : Colors.white24,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '#',
                                  style: GoogleFonts.inter(
                                    color: isActive ? Colors.white : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                phone,
                                style: GoogleFonts.inter(color: Colors.white54),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: isActive,
                                    onChanged: (val) => _toggleActive(id, isActive),
                                    activeColor: OnboardingColors.coral,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.white54),
                                    onPressed: () => _deleteContact(id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          
          const SizedBox(height: 16),
          // Add Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _addContact,
              icon: const Icon(Icons.person_add, color: OnboardingColors.coralText),
              label: Text(
                'Add from Phone',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: OnboardingColors.coralText,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: OnboardingColors.coral,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
