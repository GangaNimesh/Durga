import 'package:dio/dio.dart';
// FIX: app_models.dart lives in lib/models/, not lib/services/ — wrong relative path was a compile error.
import '../models/app_models.dart';
import 'api_client.dart';

/// Thrown by AppService methods with the server's `detail` message when
/// available, so UI code can show "Maximum of 10 emergency contacts reached"
/// instead of a raw DioException string.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

Never _rethrowAsApiException(DioException e) {
  final data = e.response?.data;
  final detail = data is Map<String, dynamic> ? data['detail'] : null;
  final message = detail is String
      ? detail
      : (e.message ?? 'Something went wrong. Please try again.');
  throw ApiException(message, statusCode: e.response?.statusCode);
}

class AppService {
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      _rethrowAsApiException(e);
    }
  }

  // Contacts
  static Future<List<Contact>> getContacts() => _guard(() async {
        final response = await ApiClient.instance.dio.get('/contacts');
        return (response.data as List).map((x) => Contact.fromJson(x)).toList();
      });

  static Future<Contact> createContact(String name, String phone, String? relation) =>
      _guard(() async {
        final response = await ApiClient.instance.dio.post(
          '/contacts',
          data: {'name': name, 'phone': phone, 'relation': relation},
        );
        return Contact.fromJson(response.data);
      });

  static Future<Contact> updateContact(
    String id, {
    String? name,
    String? phone,
    String? relation,
  }) =>
      _guard(() async {
        final data = <String, dynamic>{};
        if (name != null) data['name'] = name;
        if (phone != null) data['phone'] = phone;
        if (relation != null) data['relation'] = relation;
        final response = await ApiClient.instance.dio.patch('/contacts/$id', data: data);
        return Contact.fromJson(response.data);
      });

  static Future<void> deleteContact(String id) =>
      _guard(() => ApiClient.instance.dio.delete('/contacts/$id'));

  // SOS
  static Future<SOSAlert> triggerSOS(double? lat, double? lng) => _guard(() async {
        final response = await ApiClient.instance.dio.post(
          '/sos/trigger',
          data: {'latitude': lat, 'longitude': lng},
        );
        return SOSAlert.fromJson(response.data);
      });

  static Future<SOSAlert?> getLastSOS() => _guard(() async {
        final response = await ApiClient.instance.dio.get('/sos/last');
        return SOSAlert.fromJsonOrNull(response.data);
      });

  static Future<List<SOSAlert>> getSOSHistory({int limit = 50}) => _guard(() async {
        final response = await ApiClient.instance.dio.get(
          '/sos/history',
          queryParameters: {'limit': limit},
        );
        return (response.data as List).map((x) => SOSAlert.fromJson(x)).toList();
      });

  static Future<SOSAlert> resolveSOS(String id) => _guard(() async {
        final response = await ApiClient.instance.dio.post('/sos/$id/resolve');
        return SOSAlert.fromJson(response.data);
      });

  // Journey
  static Future<Journey> startJourney({
    double? startLat,
    double? startLng,
    double? destLat,
    double? destLng,
  }) =>
      _guard(() async {
        final response = await ApiClient.instance.dio.post(
          '/journey/start',
          data: {
            'start_latitude': startLat,
            'start_longitude': startLng,
            'dest_latitude': destLat,
            'dest_longitude': destLng,
          },
        );
        return Journey.fromJson(response.data);
      });

  static Future<Journey?> getActiveJourney() => _guard(() async {
        final response = await ApiClient.instance.dio.get('/journey/active');
        return Journey.fromJsonOrNull(response.data);
      });

  static Future<Journey> updateJourney(
    String id, {
    double? destLat,
    double? destLng,
    bool? isActive,
  }) =>
      _guard(() async {
        final data = <String, dynamic>{};
        if (destLat != null) data['dest_latitude'] = destLat;
        if (destLng != null) data['dest_longitude'] = destLng;
        if (isActive != null) data['is_active'] = isActive;
        final response = await ApiClient.instance.dio.patch('/journey/$id', data: data);
        return Journey.fromJson(response.data);
      });

  static Future<Journey> stopJourney(String id) => _guard(() async {
        final response = await ApiClient.instance.dio.post('/journey/$id/stop');
        return Journey.fromJson(response.data);
      });

  // Threat
  static Future<ThreatResponse> analyzeThreat(String text) => _guard(() async {
        final response = await ApiClient.instance.dio.post(
          '/threat/analyze',
          data: {'text': text},
        );
        return ThreatResponse.fromJson(response.data);
      });

  // Evidence
  static Future<Evidence> uploadEvidence(String filePath) => _guard(() async {
        String fileName = filePath.split('/').last;
        FormData formData = FormData.fromMap({
          "file": await MultipartFile.fromFile(filePath, filename: fileName),
        });
        final response = await ApiClient.instance.dio.post('/evidence/upload', data: formData);
        return Evidence.fromJson(response.data);
      });

  static Future<List<Evidence>> listEvidence() => _guard(() async {
        final response = await ApiClient.instance.dio.get('/evidence');
        return (response.data as List).map((x) => Evidence.fromJson(x)).toList();
      });

  static Future<void> deleteEvidence(String id) =>
      _guard(() => ApiClient.instance.dio.delete('/evidence/$id'));

  // Helplines
  static Future<List<Helpline>> getHelplines({String? category}) => _guard(() async {
        final response = await ApiClient.instance.dio.get(
          '/helplines',
          queryParameters: category != null ? {'category': category} : null,
        );
        return (response.data as List).map((x) => Helpline.fromJson(x)).toList();
      });
}
