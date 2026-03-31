import '../api/security_api.dart';

class SecurityRepository {

  final SecurityApi api = SecurityApi();

  Future<Map<String, dynamic>> validateQr(String qrData) async {
    return await api.validateQrCode(qrData);
  }

  Future<Map<String, dynamic>> updateEntryExit(String gatepassId) async {
    return await api.updateEntryExit(gatepassId);
  }

  Future<List<dynamic>> getScanLogs() async {
    return await api.fetchScanLogs();
  }
}