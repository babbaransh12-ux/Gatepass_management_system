import 'api_client.dart';
import '../../core/services/supabase_service..dart';

class WardenApi {

  final supabase = SupabaseService.client;

  Future<List<dynamic>> getPendingRequests() async {

    final response = await supabase
        .from('leave_requests')
        .select()
        .eq('status', 'pending');

    return response;

  }

  /// Get pending leave requests
  Future<dynamic> getPendingRequestsFromDB() async {

    return await ApiClient.get(
      "/warden/pending",
    );

  }

  /// Get active passes
  Future<dynamic> getActivePasses() async {
    return await ApiClient.get(
      "/warden/active-passes",
    );
  }

  /// Update parent details
  Future<dynamic> updateParent(String uid, Map<String, dynamic> data) async {
    return await ApiClient.post(
      "/warden/update-parent/$uid",
      data,
    );
  }

  /// Approve leave request
  Future<dynamic> approveRequest(String requestId) async {

    return await ApiClient.post(
      "/warden/approve/$requestId",
      {},
    );

  }

  /// Reject leave request
  Future<dynamic> rejectRequest(String requestId) async {

    return await ApiClient.post(
      "/warden/reject/$requestId",
      {},
    );

  }

  /// Generate emergency pass
  Future<dynamic> createEmergencyPass(
      Map<String, dynamic> data
      ) async {

    return await ApiClient.post(
      "/warden/emergency-pass",
      data,
    );

  }

  /// Fetch reports
  Future<dynamic> getReports(
      String startDate,
      String endDate
      ) async {

    return await ApiClient.get(
      "/warden/reports?start=$startDate&end=$endDate",
    );

  }

  /// Fetch stats for reports
  Future<dynamic> getStats() async {
    return await ApiClient.get("/warden/stats");
  }

  /// Fetch recently rejected passes
  Future<dynamic> getRejectedList() async {
    return await ApiClient.get("/warden/rejected-list");
  }

  /// Fetch pass history for a specific date
  Future<dynamic> getHistory(String date) async {
    return await ApiClient.get("/warden/history?date=$date");
  }
}