import 'package:flutter/material.dart';

import '../../features/student/qr_gatepass_screen.dart';

class ActiveGatePassScreen extends StatelessWidget {
  const ActiveGatePassScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Center(

      child: ElevatedButton(

        child: const Text("Show Gate Pass"),

        onPressed: (){

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const QRGatePassScreen(),
            ),
          );

        },

      ),

    );
  }
}