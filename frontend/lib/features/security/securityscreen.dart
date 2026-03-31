import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import '../../core/navigation/logout_button.dart';
import '../../data/api/api_client.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {

  bool scanned = false;
  bool _isLoading = false;
  String scanResult = "Scan student QR code";
  String? _lastScannedToken;
  Map<String, dynamic>? _currentEmergency;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
     _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
         try {
            final res = await ApiClient.get("/qr/active-emergencies");
            if(res is List && res.isNotEmpty) {
                 if (mounted) {
                   setState(() {
                     _currentEmergency = res.first;
                   });
                 }
            } else {
                 if (mounted && _currentEmergency != null) {
                   setState(() {
                     _currentEmergency = null;
                   });
                 }
            }
         } catch(e) {}
     });
  }

  // Replaced modal dialog with a non-blocking widget in the build method below

  @override
  void dispose() {
     _pollingTimer?.cancel();
     super.dispose();
  }

  Future<void> processQR(String code, {String? action}) async {
    setState(() {
      _isLoading = true;
      scanResult = "Verifying QR from Database...";
      _lastScannedToken = code;
    });

    try {
      String endpoint = "/qr/scan/$code";
      if (action != null) endpoint += "?action=$action";
      
      final response = await ApiClient.get(endpoint);
      
      setState(() {
        if (response['status'] == 'success') {
           scanResult = "✅ ${response['message']}";
        } else {
           scanResult = "❌ ${response['message'] ?? 'Invalid QR Gatepass'}";
        }
      });

    } catch(e) {
      setState(() {
         scanResult = "❌ Server Connection Error";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF13151A),
      appBar: AppBar(
        title: const Text("QR Security Scanner", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => LogoutService.logout(context),
          )
        ],
      ),
      body: Stack(
        children: [
          // SCANNER VIEW
          Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      onDetect: (BarcodeCapture capture) {
                        if (scanned) return;
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null) {
                            setState(() => scanned = true);
                            processQR(barcode.rawValue!);
                            break;
                          }
                        }
                      },
                    ),
                    // SCANNER OVERLAY (THE HIGH-TECH FRAME)
                    const _ScannerOverlay(),
                  ],
                ),
              ),

              // RESULT AREA
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1F26),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildResultCard(),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                scanned = false;
                                scanResult = "Ready to Scan";
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text("Scan Again"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              setState(() => _isLoading = true);
                              try {
                                final res = await ApiClient.get("/qr/active-emergencies");
                                if (res is List && res.isNotEmpty) {
                                  if (mounted) {
                                    setState(() => _currentEmergency = res.first);
                                  }
                                } else {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No active emergencies")));
                                }
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            },
                            icon: const Icon(Icons.emergency_rounded, size: 18),
                            label: const Text("Emergency"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withOpacity(0.15),
                              foregroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // EMERGENCY NOTIFICATION OVERLAY (NON-BLOCKING)
          if (_currentEmergency != null)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: _buildEmergencyBanner(_currentEmergency!),
            ),

          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF2D5AF0))),
            ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBanner(Map<String, dynamic> emergency) {
    return Card(
      elevation: 8,
      color: Colors.red.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text("🚨 EMERGENCY PASS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => setState(() => _currentEmergency = null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Allow ${emergency['student_name']} (${emergency['room']})",
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red.shade900),
                    onPressed: () => processQR(emergency['qr_token'], action: "exit"),
                    child: const Text("Mark Exit", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), foregroundColor: Colors.white),
                    onPressed: () => processQR(emergency['qr_token'], action: "entry"),
                    child: const Text("Mark Entry", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    bool isSuccess = scanResult.contains("✅");
    bool isError = scanResult.contains("❌");
    Color accentColor = isSuccess ? Colors.greenAccent : (isError ? Colors.redAccent : Colors.blueAccent);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accentColor.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(
              isSuccess ? Icons.check_circle_rounded : (isError ? Icons.error_outline_rounded : Icons.qr_code_scanner_rounded),
              color: accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSuccess ? "Scan Successful" : (isError ? "Scan Error" : "Scanner Status"),
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  scanResult.replaceAll("✅", "").replaceAll("❌", "").trim(),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                if (isSuccess) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                           if (_lastScannedToken != null) {
                             processQR(_lastScannedToken!, action: "exit");
                           }
                        },
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: const Text("Force Exit", style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      ),
                      TextButton.icon(
                        onPressed: () {
                           if (_lastScannedToken != null) {
                             processQR(_lastScannedToken!, action: "entry");
                           }
                        },
                        icon: const Icon(Icons.login_rounded, size: 16),
                        label: const Text("Force Entry", style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      ),
                    ],
                  )
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatefulWidget {
  const _ScannerOverlay();

  @override
  State<_ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<_ScannerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ScannerPainter(animationValue: _controller.value),
        );
      },
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final double animationValue;
  _ScannerPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width * 0.7;
    final double height = width;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Rect rect = Rect.fromCenter(center: center, width: width, height: height);

    // DARK OVERLAY
    final paintOverlay = Paint()..color = Colors.black.withOpacity(0.5);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paintOverlay);

    // BORDER FRAME
    final paintBorder = Paint()
      ..color = const Color(0xFF2D5AF0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)), paintBorder);

    // SCANNING LINE
    final paintLine = Paint()
      ..color = const Color(0xFF2D5AF0).withOpacity(0.6)
      ..strokeWidth = 2;
    final double lineY = rect.top + (rect.height * animationValue);
    canvas.drawLine(Offset(rect.left + 20, lineY), Offset(rect.right - 20, lineY), paintLine);

    // GLOW EFFECT FOR LINE
    final paintGlow = Paint()
      ..color = const Color(0xFF2D5AF0).withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRect(Rect.fromLTRB(rect.left + 20, lineY - 2, rect.right - 20, lineY + 2), paintGlow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}