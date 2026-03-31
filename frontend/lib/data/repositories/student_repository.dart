import '../api/student_api.dart';
import '../models/gatepass_model.dart';
import '../models/leave_request_model.dart';
import '../models/student_model.dart';

class StudentRepository {

  final StudentApi api = StudentApi();

  /// Submit leave request via Backend (triggers Twilio IVR)
  Future<dynamic> submitLeaveRequest(Map<String, dynamic> data) async {
    return await api.submitRequestToServer(data);
  }

  /// Check Status of a Request
  Future<String?> checkRequestStatus(String reqId) async {
    final Map<String, dynamic>? json = await api.checkRequestStatus(reqId);
    if (json == null) return null;
    return json["status"] as String?;
  }

  /// Upload student profile image
  Future<void> uploadProfileImage(
      String studentId,
      String imagePath,
      ) async {

    await api.uploadProfileImage(studentId, imagePath);

  }

  /// Get currently active gatepass
  Future<GatepassModel?> getActiveGatepass(String studentId) async {

    final Map<String, dynamic>? json =
    await api.fetchActiveGatepass(studentId);

    if (json == null) return null;

    return GatepassModel.fromJson(json);

  }

  /// Get leave request history
  Future<List<LeaveRequestModel>> getLeaveHistory(
      String studentId
      ) async {

    final List<dynamic> list =
    await api.fetchLeaveHistory(studentId);

    return list
        .map((e) => LeaveRequestModel.fromJson(e))
        .toList();

  }

  /// Get student profile details
  Future<StudentProfile?> getStudentProfile(String studentId) async {
    final Map<String, dynamic>? json = await api.fetchStudentProfile(studentId);
    if (json == null) return null;
    return StudentProfile.fromJson(json);
  }

}