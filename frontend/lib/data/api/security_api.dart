import 'api_client.dart';

class SecurityApi {

  /// Validate QR code when security scans it
  Future<Map<String, dynamic>> validateQrCode(String qrData) async {

    final response = await ApiClient.post(
      "/scan",
      {
        "qr": qrData,
      },
    );

    return response;
  }

  /// Update entry or exit after scan
  Future<Map<String, dynamic>> updateEntryExit(String gatepassId) async {

    final response = await ApiClient.post(
      "/scan/update",
      {
        "gatepass_id": gatepassId,
      },
    );

    return response;
  }

  /// Get scan logs (optional for admin/security dashboard)
  Future<List<dynamic>> fetchScanLogs() async {

    final response = await ApiClient.get(
      "/scan/logs",
    );

    return response;
  }

}