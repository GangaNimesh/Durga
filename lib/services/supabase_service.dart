import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Centralized Supabase service for all database operations.
///
/// Uses a device-generated UUID as the user identifier (no Supabase Auth).
/// The UUID is stored in [SharedPreferences] and created once on first launch.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  static const String _deviceIdKey = 'device_user_id';

  late final SupabaseClient _client;
  late String _userId;

  /// The current device user ID.
  String get userId => _userId;

  /// Initialize Supabase and load/create the device user ID.
  /// Must be called once in `main()` before `runApp`.
  Future<void> init({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    _client = Supabase.instance.client;

    // Load or generate device UUID
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      _userId = existing;
    } else {
      _userId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, _userId);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // USERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Create the user record if it doesn't exist. Returns the user row.
  Future<Map<String, dynamic>> getOrCreateUser() async {
    final existing = await _client
        .from('users')
        .select()
        .eq('id', _userId)
        .maybeSingle();

    if (existing != null) return existing;

    final row = {
      'id': _userId,
      'full_name': '',
      'phone': '',
      'email': '',
      'onboarding_complete': false,
      'safety_profile_complete': false,
    };

    await _client.from('users').insert(row);
    return row;
  }

  /// Update user fields (name, phone, email, flags).
  Future<void> updateUser({
    String? fullName,
    String? phone,
    String? email,
    bool? onboardingComplete,
    bool? safetyProfileComplete,
  }) async {
    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (fullName != null) data['full_name'] = fullName;
    if (phone != null) data['phone'] = phone;
    if (email != null) data['email'] = email;
    if (onboardingComplete != null) {
      data['onboarding_complete'] = onboardingComplete;
    }
    if (safetyProfileComplete != null) {
      data['safety_profile_complete'] = safetyProfileComplete;
    }

    await _client.from('users').update(data).eq('id', _userId);
  }

  /// Get the current user record, or null if not yet created.
  Future<Map<String, dynamic>?> getUser() async {
    return await _client
        .from('users')
        .select()
        .eq('id', _userId)
        .maybeSingle();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EMERGENCY CONTACTS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get all emergency contacts for the current user.
  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    return await _client
        .from('emergency_contacts')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: true);
  }

  /// Get only active emergency contacts (max 3 shown on homepage).
  Future<List<Map<String, dynamic>>> getActiveContacts() async {
    return await _client
        .from('emergency_contacts')
        .select()
        .eq('user_id', _userId)
        .eq('is_active', true)
        .order('created_at', ascending: true)
        .limit(3);
  }

  /// Add a new emergency contact.
  Future<Map<String, dynamic>> addEmergencyContact({
    required String name,
    required String phone,
    String? relation,
  }) async {
    final row = {
      'user_id': _userId,
      'name': name,
      'phone': phone,
      'relation': relation,
      'is_active': true,
    };

    final result = await _client
        .from('emergency_contacts')
        .insert(row)
        .select()
        .single();

    return result;
  }

  /// Remove an emergency contact by ID.
  Future<void> removeEmergencyContact(String contactId) async {
    await _client.from('emergency_contacts').delete().eq('id', contactId);
  }

  /// Toggle active status of a contact.
  Future<void> toggleContactActive(String contactId, bool isActive) async {
    await _client
        .from('emergency_contacts')
        .update({'is_active': isActive})
        .eq('id', contactId);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MEDICAL PROFILE
  // ═══════════════════════════════════════════════════════════════════════

  /// Get the user's medical profile, or null if not yet created.
  Future<Map<String, dynamic>?> getMedicalProfile() async {
    return await _client
        .from('medical_profile')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
  }

  /// Create or update the user's medical profile.
  Future<void> upsertMedicalProfile({
    String? bloodGroup,
    List<String>? allergies,
    List<String>? medications,
    List<String>? medicalConditions,
    String? emergencyNotes,
  }) async {
    final data = <String, dynamic>{
      'user_id': _userId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (bloodGroup != null) data['blood_group'] = bloodGroup;
    if (allergies != null) data['allergies'] = allergies;
    if (medications != null) data['medications'] = medications;
    if (medicalConditions != null) {
      data['medical_conditions'] = medicalConditions;
    }
    if (emergencyNotes != null) data['emergency_notes'] = emergencyNotes;

    await _client.from('medical_profile').upsert(
      data,
      onConflict: 'user_id',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PERMISSIONS STATUS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get the user's permissions status, or null if not yet created.
  Future<Map<String, dynamic>?> getPermissions() async {
    return await _client
        .from('permissions_status')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
  }

  /// Create or update the user's permissions status.
  Future<void> updatePermissions({
    bool? contacts,
    bool? notifications,
    bool? camera,
    bool? microphone,
    bool? location,
    bool? gallery,
  }) async {
    final data = <String, dynamic>{
      'user_id': _userId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (contacts != null) data['contacts'] = contacts;
    if (notifications != null) data['notifications'] = notifications;
    if (camera != null) data['camera'] = camera;
    if (microphone != null) data['microphone'] = microphone;
    if (location != null) data['location'] = location;
    if (gallery != null) data['gallery'] = gallery;

    await _client.from('permissions_status').upsert(
      data,
      onConflict: 'user_id',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ONBOARDING HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Mark onboarding as complete in Supabase.
  Future<void> markOnboardingComplete() async {
    await getOrCreateUser(); // ensure user exists
    await updateUser(onboardingComplete: true);
  }

  /// Mark safety profile as complete in Supabase.
  Future<void> markSafetyProfileComplete() async {
    await updateUser(safetyProfileComplete: true);
  }

  /// Calculate safety profile completion percentage.
  /// Factors: medical profile exists (40%) + all permissions granted (60%)
  Future<int> getSafetyProfilePercentage() async {
    int score = 0;

    // Medical profile: 40%
    final medical = await getMedicalProfile();
    if (medical != null) {
      final hasBloodGroup =
          medical['blood_group'] != null && medical['blood_group'] != '';
      final hasAllergies =
          medical['allergies'] != null && (medical['allergies'] as List).isNotEmpty;
      final hasMedications =
          medical['medications'] != null && (medical['medications'] as List).isNotEmpty;

      if (hasBloodGroup) score += 15;
      if (hasAllergies || hasMedications) score += 25;
    }

    // Permissions: 60%
    final perms = await getPermissions();
    if (perms != null) {
      final permKeys = ['contacts', 'notifications', 'camera', 'microphone', 'location', 'gallery'];
      int granted = 0;
      for (final key in permKeys) {
        if (perms[key] == true) granted++;
      }
      score += ((granted / permKeys.length) * 60).round();
    }

    return score.clamp(0, 100);
  }
}
