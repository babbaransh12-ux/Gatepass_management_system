import 'dart:async';

import 'package:e_gatepass/core/constants/appcolors.dart';
import 'package:e_gatepass/core/navigation/role_router.dart';
import 'package:e_gatepass/core/services/auth_service.dart';
import 'package:e_gatepass/shared/widgets/uihelper.dart';
import 'package:flutter/material.dart';

import 'loginscreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<StatefulWidget> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  void checkLogin() async {

    String? role = await AuthService.getRole();

    Timer(const Duration(seconds: 3), () {

      if (!mounted) return;

      if (role != null) {

        /// user already logged in
        RoleRouter.navigate(context, role);

      } else {

        /// user not logged in
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(),
          ),
        );

      }

    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.scaffoldbackground,

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            /// App Logo
            Uihelper.CustomImage(img: "logo.png"),

            const SizedBox(height: 20),

            const Text(
              "AI Gate Pass System",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const CircularProgressIndicator()

          ],
        ),
      ),
    );

  }
}