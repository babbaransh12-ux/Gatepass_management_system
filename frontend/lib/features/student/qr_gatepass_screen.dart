import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/services/auth_service.dart';
import '../../data/api/api_client.dart';

class QRGatePassScreen extends StatefulWidget {
  final String qrToken;
  const QRGatePassScreen({super.key, this.qrToken = "DUMMY_TOKEN"});

  @override
  State<QRGatePassScreen> createState() => _QRGatePassScreenState();
}

class _QRGatePassScreenState extends State<QRGatePassScreen> {
  bool _isExitDone = false;
  bool _isEntryDone = false;
  bool _isLoading = true;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    ScreenProtector.preventScreenshotOn();
    _fetchStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchStatus());
  }

  Future<void> _fetchStatus() async {
    try {
      final uid = await AuthService.getUid();
      final res = await ApiClient.get("/student/active-pass/${uid ?? ''}");
      if (res != null && res["data"] != null) {
        final data = res["data"];
        if (mounted) {
          setState(() {
            _isExitDone = data["exit_time"] != null;
            _isEntryDone = data["entry_time"] != null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching QR status: $e");
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    ScreenProtector.preventScreenshotOff();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = _isExitDone && _isEntryDone;

    return PopScope(
      canPop: isCompleted, // Only allow exit if pass is completed
      onPopInvoked: (didPop) {
        if (!didPop && !isCompleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cannot go back while Gate Pass is active")),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        appBar: AppBar(
          title: const Text("Gate Pass QR"),
          backgroundColor: const Color(0xFF2D5AF0),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: isCompleted, // Hide back button if not completed
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isCompleted) ...[
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
                    const SizedBox(height: 20),
                    const Text(
                      "Gate Pass Completed",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 10),
                    const Text("You have successfully checked out and back in."),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D5AF0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      ),
                      child: const Text("Go to Home"),
                    )
                  ] else ...[
                    const Text(
                      "Active Gate Pass",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Show this QR for Entry/Exit at the Gate",
                      textAlign: TextAlign.center,
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
                          ]),
                      child: QrImageView(
                        data: widget.qrToken,
                        size: 250,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildStatusStep("Exit", _isExitDone),
                    const SizedBox(height: 12),
                    _buildStatusStep("Entry", _isEntryDone),
                    const SizedBox(height: 40),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.security, color: Colors.blueAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Verified by Campus Security",
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueAccent),
                        )
                      ],
                    )
                  ],
                ],
              ),
            ),
          ),
      ),
    );
  }

  Widget _buildStatusStep(String label, bool isDone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDone ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.pending_rounded,
            color: isDone ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 15),
          Text(
            label,
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold,
              color: isDone ? Colors.green.shade700 : Colors.black87,
              decoration: isDone ? TextDecoration.lineThrough : null,
            ),
          ),
          const Spacer(),
          if (isDone)
            const Text("Done", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
          else
            const Text("Pending", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
        ],
      ),
    );
  }
}