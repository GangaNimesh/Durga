class Contact {
  final String id;
  final String name;
  final String phone;
  final String? relation;
  final DateTime? createdAt;

  Contact({
    required this.id,
    required this.name,
    required this.phone,
    this.relation,
    this.createdAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      relation: json['relation'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'relation': relation,
    };
  }
}

class SOSAlert {
  final String id;
  final bool isActive;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;

  SOSAlert({
    required this.id,
    required this.isActive,
    required this.createdAt,
    this.latitude,
    this.longitude,
  });

  factory SOSAlert.fromJson(Map<String, dynamic> json) {
    return SOSAlert(
      id: json['id'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// GET /sos/last returns `null` when there is no active alert - that's a
  /// normal state, not an error, so this must tolerate a null body.
  static SOSAlert? fromJsonOrNull(dynamic json) {
    if (json == null) return null;
    return SOSAlert.fromJson(json as Map<String, dynamic>);
  }
}

class Journey {
  final String id;
  final bool isActive;
  final DateTime createdAt;
  final double? startLatitude;
  final double? startLongitude;
  final double? destLatitude;
  final double? destLongitude;

  Journey({
    required this.id,
    required this.isActive,
    required this.createdAt,
    this.startLatitude,
    this.startLongitude,
    this.destLatitude,
    this.destLongitude,
  });

  factory Journey.fromJson(Map<String, dynamic> json) {
    return Journey(
      id: json['id'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      startLatitude: (json['start_latitude'] as num?)?.toDouble(),
      startLongitude: (json['start_longitude'] as num?)?.toDouble(),
      destLatitude: (json['dest_latitude'] as num?)?.toDouble(),
      destLongitude: (json['dest_longitude'] as num?)?.toDouble(),
    );
  }

  static Journey? fromJsonOrNull(dynamic json) {
    if (json == null) return null;
    return Journey.fromJson(json as Map<String, dynamic>);
  }
}

class Evidence {
  final String id;
  final String fileType;
  final DateTime createdAt;

  Evidence({
    required this.id,
    required this.fileType,
    required this.createdAt,
  });

  factory Evidence.fromJson(Map<String, dynamic> json) {
    return Evidence(
      id: json['id'] as String? ?? '',
      fileType: json['file_type'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class Helpline {
  final String id;
  final String name;
  final String phone;
  final String? category;

  const Helpline({
    required this.id,
    required this.name,
    required this.phone,
    this.category,
  });

  factory Helpline.fromJson(Map<String, dynamic> json) {
    return Helpline(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      category: json['category'] as String?,
    );
  }
}

class ThreatResponse {
  final String riskLevel;
  final String color;
  final int score;
  final List<String> matchedKeywords;

  ThreatResponse({
    required this.riskLevel,
    required this.color,
    this.score = 0,
    this.matchedKeywords = const [],
  });

  factory ThreatResponse.fromJson(Map<String, dynamic> json) {
    return ThreatResponse(
      riskLevel: json['risk_level'] as String? ?? 'Low Risk',
      color: json['color'] as String? ?? 'green',
      score: json['score'] as int? ?? 0,
      matchedKeywords: (json['matched_keywords'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}
