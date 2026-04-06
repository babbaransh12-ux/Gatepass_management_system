import 'dart:async';
import 'package:flutter/material.dart';

import 'qr_gatepass_screen.dart';
import '../../core/services/auth_service.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/student_repository.dart';

class RequestStatusScreen extends StatefulWidget {
  final String reqId;
  const RequestStatusScreen({super.key, required this.reqId});

  @override
  State<RequestStatusScreen> createState() => _RequestStatusScreenState();
}

class _RequestStatusScreenState extends State<RequestStatusScreen> {

  int currentStep = 0;
  int _attempts = 1;
  String? _status;

  final steps = [
    "Request Submitted",
    "Waiting for Parent Approval",
    "Waiting for Warden Approval",
    "Generating QR Gate Pass"
  ];

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    startPolling();
  }

  void startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final uid = await AuthService.getUid();
        final res = await ApiClient.get("/student/active-pass/${uid ?? ''}");
        
        if (mounted && res != null && res["data"] != null) {
          final data = res["data"];
          final status = data["Status"];
          final attempts = data["attempts"] ?? 1;
          
          setState(() {
            _attempts = attempts;
            _status = status;
          });

          if (status == "Pending") {
            setState(() => currentStep = 1); 
          } else if (status == "Parent_Approved") {
            setState(() => currentStep = 2); 
          } else if (status == "Approved") {
            final qrToken = data["qr_token"] ?? "UNKNOWN_TOKEN";
            setState(() => currentStep = 3);
            timer.cancel();
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => QRGatePassScreen(qrToken: qrToken)),
                );
              }
            });
          } else if (status == "Rejected") {
            timer.cancel();
            _showRejectionDialog();
          } else if (status == "Emergency") {
             timer.cancel();
          }
        }
      } catch (e) {
        // Silently ignore
      }
    });
  }

  void _showRejectionDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Request Rejected"),
        content: const Text("Your leave request has been rejected by your parent or the warden."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Go back to student screen
            },
            child: const Text("Go Back"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Status"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pending_actions, size: 80, color: Colors.indigo),
            const SizedBox(height: 30),
            const Text(
              "Processing Your Request",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            if (_status == "Emergency") ...[
              _buildEmergencyAlert(),
              const SizedBox(height: 20),
            ],
            
            Expanded(
              child: Stepper(
                physics: const ClampingScrollPhysics(),
                currentStep: currentStep,
                controlsBuilder: (context, details) => const SizedBox(),
                steps: [
                  Step(
                    title: const Text("Request Submitted"),
                    content: const Text("Leave request received"),
                    isActive: currentStep >= 0,
                    state: currentStep > 0 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text("Parent Approval"),
                    content: Text("Calling parent via IVR\n(Attempt $_attempts/3)"),
                    isActive: currentStep >= 1,
                    state: _status == "Emergency" ? StepState.error : (currentStep > 1 ? StepState.complete : StepState.indexed),
                  ),
                  Step(
                    title: const Text("Warden Approval"),
                    content: const Text("Warden reviewing request"),
                    isActive: currentStep >= 2,
                    state: currentStep > 2 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text("QR Generated"),
                    content: const Text("Gate pass ready"),
                    isActive: currentStep >= 3,
                    state: currentStep >= 3 ? StepState.complete : StepState.indexed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text("Parents Unreachable", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "We tried calling your parents but couldn't connect. Please visit the Warden office for an emergency pass.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}