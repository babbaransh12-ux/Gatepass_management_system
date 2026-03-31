import 'package:flutter/material.dart';

import '../../features/student/studentscreen.dart';
import '../../features/warden/wardenscreen.dart';
import '../../features/security/securityscreen.dart';

class RoleRouter {

  static void navigate(BuildContext context, String role) {

    Widget screen;

    switch (role) {

      case "Student":
        screen = const StudentScreen();
        break;

      case "Warden":
        screen = const WardenScreen();
        break;

      case "Security":
        screen = const SecurityScreen();
        break;

      default:
        screen = const StudentScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => screen,
      ),
    );
  }
}