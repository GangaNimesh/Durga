import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../models/app_models.dart';
import '../../services/app_service.dart';

class ContactsCard extends StatefulWidget {
  const ContactsCard({super.key});

  @override
  State<ContactsCard> createState() => _ContactsCardState();
}

class _ContactsCardState extends State<ContactsCard> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  List<Contact> contacts = [];
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final result = await AppService.getContacts();
      setState(() => contacts = result);
    } catch (e) {
      setState(() => error = 'Could not load contacts: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _add() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter both a name and a phone number')),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      await AppService.createContact(name, phone, null);
      nameController.clear();
      phoneController.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save contact: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _delete(Contact contact) async {
    try {
      await AppService.deleteContact(contact.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete contact: $e')),
        );
      }
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
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: AppColors.primary),
              const SizedBox(width: 10),
              const Text(
                "Trusted Contacts",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${contacts.length}/10',
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ))
          else if (error != null)
            Text(error!, style: const TextStyle(color: Colors.orange))
          else if (contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No trusted contacts yet — add one below.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...contacts.map(
              (c) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xffF4F6FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(c.phone, style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _delete(c),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: "Contact name",
              filled: true,
              fillColor: const Color(0xffF4F6FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: "Enter phone number",
              filled: true,
              fillColor: const Color(0xffF4F6FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: (isSaving || contacts.length >= 10) ? null : _add,
              child: Text(
                isSaving
                    ? "Saving..."
                    : contacts.length >= 10
                        ? "Contact limit reached"
                        : "Save Trusted Contact",
              ),
            ),
          ),
        ],
      ),
    );
  }
}
