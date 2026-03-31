import '../api/warden_api.dart';
import '../models/leave_request_model.dart';

class WardenRepository {

  final WardenApi api = WardenApi();

  /// Fetch pending leave requests for warden dashboard
  Future<List<LeaveRequestModel>> fetchPendingRequests() async {

    final List<dynamic> data = await api.getPendingRequestsFromDB();

    return data
        .map((e) => LeaveRequestModel.fromJson(e))
        .toList();
  }

  /// Fetch active passes for warden dashboard
  Future<List<LeaveRequestModel>> fetchActivePasses() async {
    final List<dynamic> data = await api.getActivePasses();
    return data
        .map((e) => LeaveRequestModel.fromJson(e))
        .toList();
  }

  /// Update parent details
  Future<void> updateParentDetails(String uid, Map<String, dynamic> data) async {
    await api.updateParent(uid, data);
  }

  /// Approve student leave request
  Future<void> approveRequest(String requestId) async {

    await api.approveRequest(requestId);

  }

  /// Reject student leave request
  Future<void> rejectRequest(String requestId) async {

    await api.rejectRequest(requestId);

  }

  /// Generate emergency gatepass
  Future<void> generateEmergencyPass(Map<String, dynamic> data) async {

    await api.createEmergencyPass(data);

  }

  /// Fetch stats for reports
  Future<Map<String, dynamic>> fetchStats() async {
    return await api.getStats();
  }

  /// Fetch recently rejected passes
  Future<List<LeaveRequestModel>> fetchRejectedList() async {
    final List<dynamic> data = await api.getRejectedList();
    return data.map((e) => LeaveRequestModel.fromJson(e)).toList();
  }

  /// Fetch pass history for a specific date
  Future<List<LeaveRequestModel>> fetchHistory(String date) async {
    final List<dynamic> data = await api.getHistory(date);
    return data.map((e) => LeaveRequestModel.fromJson(e)).toList();
  }

  /// Fetch reports for analytics screen
  Future<Map<String, dynamic>> fetchReports(
      String startDate,
      String endDate,
      ) async {

    final response = await api.getReports(startDate, endDate);

    return response;

  }

}