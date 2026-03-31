import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../../core/services/supabase_service..dart';
import '../../core/services/auth_service.dart';

class StudentApi {

  final supabase = SupabaseService.client;

  /// Submit leave request to Supabase (direct DB) - (Deprecated, use backend)
  Future<void> submitRequestToSupabase(Map<String, dynamic> data) async {
    await supabase
        .from('leave_requests')
        .insert(data);
  }

  /// Get status of a request
  Future<dynamic> checkRequestStatus(String reqId) async {
    return await ApiClient.get("/student/status/$reqId");
  }

  /// Submit leave request via backend API
  Future<dynamic> submitRequestToServer(Map<String, dynamic> data) async {
    return await ApiClient.post(
      "/student/request",
      data,
    );
  }

  /// Get active gatepass
  Future<dynamic> fetchActiveGatepass(String studentId) async {
    return await ApiClient.get(
      "/student/active-pass/$studentId",
    );
  }

  /// Leave history
  Future<dynamic> fetchLeaveHistory(String studentId) async {
    return await ApiClient.get(
      "/student/history/$studentId",
    );
  }

  /// Upload profile image (multipart form-data)
  Future<dynamic> uploadProfileImage(
      String studentId,
      String imagePath,
      ) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse("${ApiClient.baseUrl}/student/upload-image");
    final request = http.MultipartRequest('POST', uri);
    
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['student_id'] = studentId;
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return ApiClient.handleResponse(response);
  }

  /// Get student profile
  Future<dynamic> fetchStudentProfile(String studentId) async {
    return await ApiClient.get("/student/profile/$studentId");
  }
}