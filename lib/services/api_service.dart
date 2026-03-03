import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/classification_record.dart';

class ApiService {
  // ── Base URL ──────────────────────────────────────────────────────────────
  // Android emulator  →  http://10.0.2.2:3000/api
  // iOS simulator     →  http://localhost:3000/api
  // Physical device   →  http://<YOUR_MACHINE_LAN_IP>:3000/api  (e.g. 192.168.1.5)
  // Production        →  https://your-domain.com/api
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  final Dio _dio;

  /// [authToken] is the Supabase JWT access token. When provided it is sent
  /// as `Authorization: Bearer <token>` on every request.
  ApiService({String? authToken})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            if (authToken != null) 'Authorization': 'Bearer $authToken',
          },
        ),
      );

  // ── History CRUD ──────────────────────────────────────────────────────────

  /// Upload a classification record + image to the backend.
  /// Returns the saved record with its server-assigned id and imageUrl.
  Future<ClassificationRecord> saveRecord(
    ClassificationRecord record,
    File imageFile,
  ) async {
    final formData = FormData.fromMap({
      'label': record.label,
      'confidence': record.confidence.toString(),
      // Nested objects are sent as a JSON string; the backend parses them back.
      'topResults': jsonEncode(
        record.topResults.map((r) => r.toJson()).toList(),
      ),
      'timestamp': record.timestamp.toIso8601String(),
      'localImagePath': record.localImagePath,
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'banknote_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });

    final response = await _dio.post('/history', data: formData);
    return ClassificationRecord.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  /// Fetch all history records, newest first.
  Future<List<ClassificationRecord>> fetchHistory() async {
    final response = await _dio.get('/history');
    return (response.data['data'] as List<dynamic>)
        .map((e) => ClassificationRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single record by id.
  Future<ClassificationRecord> fetchRecord(String id) async {
    final response = await _dio.get('/history/$id');
    return ClassificationRecord.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  /// Delete a record by id.
  Future<void> deleteRecord(String id) async {
    await _dio.delete('/history/$id');
  }
}
