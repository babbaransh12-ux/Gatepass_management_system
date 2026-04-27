import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../../core/navigation/logout_button.dart';
import '../../data/api/api_client.dart';

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

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
  Map<String, dynamic>? _lastScannedStudent;
  List<dynamic> _recentLogs = [];
  Map<String, dynamic>? _currentEmergency;
  Timer? _pollingTimer;
  Timer? _logRefreshTimer;
  final MobileScannerController scannerController = MobileScannerController();
  bool _canUndo = false;
  String? _undoToken;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _fetchRecentLogs();
    // Auto-refresh logs every 5 seconds so guard sees real-time updates
    _logRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchRecentLogs());
  }

  Future<void> _fetchRecentLogs() async {
    try {
      final logs = await ApiClient.get("/qr/recent-logs");
      if (logs is List) {
        if (mounted) setState(() => _recentLogs = logs);
      }
    } catch (e) {
      debugPrint("Error fetching logs: $e");
    }
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
                    scannerController.stop(); // 🛑 STOP SCANNER TO FIX LAG
                  }
             } else {
                  if (mounted && _currentEmergency != null) {
                    setState(() {
                      _currentEmergency = null;
                    });
                    scannerController.start(); // ▶️ RESUME SCANNER
                  }
             }
         } catch(e) {}
     });
  }

  @override
  void dispose() {
     _pollingTimer?.cancel();
     _logRefreshTimer?.cancel();
     scannerController.dispose();
     super.dispose();
  }

  Future<void> processQR(String code, {String? action}) async {
    setState(() {
      _isLoading = true;
      scanResult = action == null ? "Fetching Student Identity..." : "Recording ${action.capitalize()}...";
      _lastScannedToken = code;
    });

    try {
      if (action == null) {
        // Step 1: Initial Scan - Just fetch info
        final response = await ApiClient.get("/qr/scan/$code");
        setState(() {
          if (response != null && response['status'] == 'success') {
             scanResult = "Student Identity Verified";
             _lastScannedStudent = response;
          } else {
             final msg = response?['message'] ?? response?['detail'] ?? 'Invalid QR Gatepass';
             scanResult = "❌ $msg";
             _lastScannedStudent = null;
          }
        });
      } else {
        // Step 2: Confirmation - Update DB
        final response = await ApiClient.post("/qr/scan/$code?action=$action", {});
        setState(() {
          if (response != null && response['status'] == 'success') {
             scanResult = "✅ ${response['message']}";
             _canUndo = true;
             _undoToken = code;
             _fetchRecentLogs();

             // 🔄 UPDATE UI CACHE IMMEDIATELY
             if (_lastScannedStudent != null && _lastScannedStudent!['request'] != null) {
                _lastScannedStudent!['request']['Status'] = (action == 'exit') ? 'Exit' : 'Completed';
             }

             // Reset profile after 3 seconds or on next scan
             Future.delayed(const Duration(seconds: 3), () {
                if (mounted && scanResult.contains("✅")) {
                   setState(() {
                      scanned = false;
                      _lastScannedStudent = null;
                      scanResult = "Scan student QR code";
                   });
                }
             });
          } else {
             scanResult = "❌ Error: ${response?['message'] ?? 'Failed to update'}";
          }
        });
      }
    } catch(e) {
      setState(() => scanResult = "❌ Error: ${e.toString().split(':').last.trim()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _undoLastScan() async {
    if (_undoToken == null) return;
    setState(() => _isLoading = true);
    try {
      await ApiClient.post("/qr/undo-scan/$_undoToken", {});
      setState(() {
        _canUndo = false;
        scanResult = "⏪ Last scan reverted";
        _lastScannedStudent = null;
        scanned = false;
      });
      _fetchRecentLogs();
    } catch (e) {
      debugPrint("Undo failed: $e");
    } finally {
      setState(() => _isLoading = false);
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
                      controller: scannerController,
                      onDetect: (BarcodeCapture capture) {
                        if (scanned || _currentEmergency != null) return;
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1F26),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildResultCard(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                scanned = false;
                                scanResult = "Ready to Scan";
                                _lastScannedStudent = null;
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text("Scan Next"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () {
                             _showEmergencyDialog();
                          },
                          icon: const Icon(Icons.emergency_rounded, color: Colors.redAccent),
                          tooltip: "Emergency Pass",
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.1),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _fetchRecentLogs,
                          icon: const Icon(Icons.history_rounded, color: Colors.white70),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.05),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                        if (_canUndo) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: _undoLastScan,
                            icon: const Icon(Icons.undo_rounded, color: Colors.orangeAccent),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.orangeAccent.withOpacity(0.1),
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildRecentLogsSection(),
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
                  onPressed: () {
                    setState(() => _currentEmergency = null);
                    scannerController.start();
                  },
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
                    onPressed: () {
                      processQR(emergency['qr_token'], action: "exit");
                      setState(() => _currentEmergency = null);
                      scannerController.start();
                    },
                    child: const Text("Mark Exit", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), foregroundColor: Colors.white),
                    onPressed: () {
                      processQR(emergency['qr_token'], action: "entry");
                      setState(() => _currentEmergency = null);
                      scannerController.start();
                    },
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

  Widget _buildRecentLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.access_time_rounded, color: Colors.white38, size: 16),
            SizedBox(width: 8),
            Text("RECENT ENTRIES", style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: _recentLogs.isEmpty
              ? const Center(child: Text("No recent entries", style: TextStyle(color: Colors.white24, fontSize: 13)))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentLogs.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final log = _recentLogs[index];
                    final String rawAction = (log['Action'] ?? log['action'] ?? '').toString().toLowerCase();
                    // Skip stale records that are not valid gate actions
                    if (rawAction != 'exit' && rawAction != 'entry') return const SizedBox.shrink();
                    String time = "";
                    try {
                        DateTime dt = DateTime.parse(log['Timestamp'] ?? log['timestamp']);
                        time = DateFormat("h:mm a").format(dt);
                    } catch(e) {}
                    
                    bool isEntry = rawAction.contains('entry');

                    return Container(
                      width: 110,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: NetworkImage(log['student_image']),
                            backgroundColor: Colors.white10,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            log['student_name'].split(' ').first,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEntry ? "ENTRY" : "EXIT",
                            style: TextStyle(color: isEntry ? Colors.blueAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                          Text(time, style: const TextStyle(color: Colors.white38, fontSize: 9)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    bool isSuccess = scanResult.contains("✅") || scanResult == "Student Identity Verified";
    bool isError = scanResult.contains("❌");
    Color accentColor = isSuccess ? Colors.greenAccent : (isError ? Colors.redAccent : Colors.blueAccent);

    if (isSuccess && _lastScannedStudent != null) {
      return _buildProfileResult(_lastScannedStudent!);
    }

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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileResult(Map<String, dynamic> data) {
    final student = data['student'];
    final req = data['request'];

    final String reqStatus = req != null ? (req['Status'] ?? '').toString() : '';
    final bool exitDone = reqStatus == 'Exit' || reqStatus == 'Completed';
    final bool entryDone = reqStatus == 'Completed';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2D5AF0), width: 2),
                  image: DecorationImage(
                    image: NetworkImage(student['photo'] ?? 'https://ui-avatars.com/api/?name=${student['name']}'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student['name'].toString().toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "ID: ${student['uid']}",
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      student['dept'] ?? "General",
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statusChip("Exit", exitDone),
                        _statusChip("Entry", entryDone),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Show only the relevant next action based on current pass state
          if (!exitDone && (reqStatus == 'Approved' || reqStatus == 'Emergency' || reqStatus == 'Warden_Approved'))
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => processQR(_lastScannedToken!, action: "exit"),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text("Confirm Exit"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else if (exitDone && !entryDone)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => processQR(_lastScannedToken!, action: "entry"),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text("Confirm Entry (Return)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 8),
                  Text("Pass Completed - No Action Needed", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  scanned = false;
                  _lastScannedStudent = null;
                  scanResult = "Scan student QR code";
                });
                scannerController.start();
              },
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text("Reject / Clear"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: done ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: done ? Colors.greenAccent.withOpacity(0.5) : Colors.orange.withOpacity(0.4)),
      ),
      child: Text(
        "$label: ${done ? 'Done' : 'Pending'}",
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: done ? Colors.greenAccent : Colors.orangeAccent,
        ),
      ),
    );
  }

  void _showEmergencyDialog() {
    final TextEditingController uidController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F26),
        title: const Text("Manual Emergency Pass", style: TextStyle(color: Colors.redAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter Student ID to fetch their gatepass manually.", style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: uidController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter UID (e.g. 23BDS001)",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final uid = uidController.text.trim();
              if (uid.isNotEmpty) {
                 Navigator.pop(ctx);
                 processQR(uid);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text("Search"),
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