import 'package:flutter/material.dart';
import '../../features/auth/loginscreen.dart';
import '../../core/services/auth_service.dart';

class LogoutService {

  static Future<void> logout(BuildContext context) async {
    await AuthService.logout();
    
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(),
        ),
        (route) => false,
      );
    }
  }

}