import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRGatePassScreen extends StatefulWidget {
  final String qrToken; // Pass the actual token from the API
  const QRGatePassScreen({super.key, this.qrToken = "DUMMY_TOKEN"});

  @override
  State<QRGatePassScreen> createState() => _QRGatePassScreenState();
}

class _QRGatePassScreenState extends State<QRGatePassScreen> {

  @override
  void initState() {
    super.initState();
    ScreenProtector.preventScreenshotOn();
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Gate Pass QR"),
        backgroundColor: const Color(0xFF2D5AF0),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Active Gate Pass",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Present this QR code to the Security Guard",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ]
              ),
              child: QrImageView(
                data: widget.qrToken,
                size: 250,
              ),
            ),
            const SizedBox(height: 40),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  "Secured by Campus Security",
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}