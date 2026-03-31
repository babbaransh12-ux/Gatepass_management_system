import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {

  static Future<String> getDeviceId() async {

    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      return android.id; // ANDROID_ID
    }

    if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      return ios.identifierForVendor ?? "unknown";
    }

    return "unknown";
  }
}