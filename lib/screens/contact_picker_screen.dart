import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/onboarding_colors.dart';

class ContactPickerScreen extends StatefulWidget {
  const ContactPickerScreen({super.key});

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  List<Contact> _contacts = [];
  List<Contact> _filtered = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    if (await FlutterContacts.requestPermission(readonly: true)) {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      // Only show contacts with phones
      final withPhones = contacts.where((c) => c.phones.isNotEmpty).toList();
      withPhones.sort((a, b) => a.displayName.compareTo(b.displayName));
      
      if (mounted) {
        setState(() {
          _contacts = withPhones;
          _filtered = withPhones;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission denied')),
        );
      }
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _filtered = _contacts
          .where((c) => c.displayName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search contacts...',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onChanged: _onSearch,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: OnboardingColors.coral))
          : ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final contact = _filtered[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: OnboardingColors.coral,
                    child: Text(
                      contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    contact.displayName,
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    contact.phones.first.number,
                    style: GoogleFonts.inter(color: Colors.white54),
                  ),
                  onTap: () {
                    Navigator.pop(context, contact);
                  },
                );
              },
            ),
    );
  }
}
