import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'request_status_screen.dart';
import 'history_screen.dart';
import 'qr_gatepass_screen.dart';
import '../../../core/navigation/logout_button.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/student_model.dart';
import '../../../data/repositories/student_repository.dart';
import '../../services/notification_service.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {

  final reasonController = TextEditingController();
  final destinationController = TextEditingController();

  String selectedLanguage = "English";
  String selectedParent = "";

  DateTime? leaveDate;
  final durationController = TextEditingController(text: "24");
  String durationUnit = "Hours";

  Timer? _cooldownTimer;
  int _currentCooldownMs = 0;

  bool _isLoadingProfile = true;
  StudentProfile? _profile;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    NotificationService.init(context);
  }
  
  @override
  void dispose() {
    _cooldownTimer?.cancel();
    NotificationService.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final uid = await AuthService.getUid();
      if (uid == null) throw Exception("No user ID found in session");

      final repo = StudentRepository();
      final profile = await repo.getStudentProfile(uid);
      if (mounted && profile != null) {
        setState(() {
          _profile = profile;
          _isLoadingProfile = false;
          _currentCooldownMs = profile.cooldownRemainingMs;
        });

        // 🚪 REDIRECT IF ACTIVE GATEPASS EXISTS
        if (profile.activeReqId != null && profile.exitTime == null) {
          if (profile.qrToken != null) {
             Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => QRGatePassScreen(qrToken: profile.qrToken!)),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => RequestStatusScreen(reqId: profile.activeReqId.toString())),
            );
          }
          return;
        }

        // ⏳ START COOLDOWN TIMER
        if (_currentCooldownMs > 0) {
          _startCooldownTimer();
        }
      } else {
        throw Exception("Failed to load profile");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _profile = StudentProfile(
             id: "Fallback-ID",
             name: "Offline Mode",
             parents: [ParentContact(name: "Demo", phone: "0000000000", relation: "Father")],
             profileUrl: null
          );
          _isLoadingProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Backend error: using fallback profile - $e")));
      }
    }
  }

  bool _isUploadingPic = false;

  bool _isSubmitting = false;

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentCooldownMs > 1000) {
        if (mounted) setState(() => _currentCooldownMs -= 1000);
      } else {
        timer.cancel();
        if (mounted) setState(() => _currentCooldownMs = 0);
      }
    });
  }

  String _formatCooldown(int ms) {
    Duration duration = Duration(milliseconds: ms);
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int seconds = duration.inSeconds.remainder(60);
    return "${hours}h ${minutes}m ${seconds}s";
  }

  /// Form validation
  bool get isFormValid {
    return reasonController.text.isNotEmpty &&
        destinationController.text.isNotEmpty &&
        durationController.text.isNotEmpty &&
        leaveDate != null &&
        selectedParent.isNotEmpty &&
        (_profile?.profileUrl != null);
  }

  /// Date picker
  void pickDate() async {

    DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        leaveDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        drawer: SafeArea(child: _buildDrawer()),
        body: _isLoadingProfile
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildInfoCards(),
                        const SizedBox(height: 32),
                        if (_currentCooldownMs > 0) _buildCooldownHeader(),
                        if (_profile?.history.isNotEmpty ?? false) _buildRecentActivity(),
                        const SizedBox(height: 32),
                        _buildRequestForm(),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D5AF0), Color(0xFF7B4DFF)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      padding: const EdgeInsets.only(top: 24, bottom: 40, left: 24, right: 24),
      child: Column(
        children: [
          Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              const SizedBox(width: 12),
              // PROFILE IMAGE
                Hero(
                  tag: "student_profile",
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage: (_profile?.profileUrl != null
                                  ? NetworkImage(_profile!.profileUrl!) as ImageProvider
                                  : null),
                          child: (_profile?.profileUrl == null)
                              ? const Icon(Icons.person_outline_rounded, color: Colors.white, size: 28)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profile?.name ?? "Student",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "ID: ${_profile?.id ?? 'N/A'}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 22),
                  onPressed: () => LogoutService.logout(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF2D5AF0), const Color(0xFF2D5AF0).withOpacity(0.8)],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage: _profile?.profileUrl != null ? NetworkImage(_profile!.profileUrl!) : null,
                  child: _profile?.profileUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile?.name ?? "Student",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "ID: ${_profile?.id ?? 'N/A'}",
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _drawerItem(
            icon: Icons.add_circle_outline_rounded,
            title: "New Request",
            onTap: () => Navigator.pop(context),
            isSelected: true,
          ),
          if (_profile?.activeReqId != null)
            _drawerItem(
              icon: Icons.pending_actions_rounded,
              title: "Active Status",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RequestStatusScreen(reqId: _profile!.activeReqId.toString())),
                );
              },
            ),
          _drawerItem(
            icon: Icons.history_rounded,
            title: "Request History",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentHistoryScreen()),
              );
            },
          ),
          const Spacer(),
          const Divider(),
          _drawerItem(
            icon: Icons.help_outline_rounded,
            title: "Help & Support",
            onTap: () {},
          ),
          _drawerItem(
            icon: Icons.logout_rounded,
            title: "Logout",
            color: Colors.redAccent,
            onTap: () => LogoutService.logout(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? (isSelected ? const Color(0xFF2D5AF0) : Colors.grey.shade600), size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? (isSelected ? const Color(0xFF2D5AF0) : Colors.grey.shade800),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildInfoCards() {
    return Row(
      children: [
        Expanded(
          child: _infoTile(
            icon: Icons.meeting_room_rounded,
            title: "Room",
            value: _profile?.roomNo ?? "N/A",
            color: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _infoTile(
            icon: Icons.school_rounded,
            title: "Course",
            value: _profile?.course ?? "N/A",
            color: const Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }

  Widget _infoTile({required IconData icon, required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1C21)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Color(0xFF2D5AF0)),
              SizedBox(width: 12),
              Text(
                "Leave Request Form",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C21)),
              ),
            ],
          ),
          const SizedBox(height: 28),

          _formLabel("Reason for Leave"),
          const SizedBox(height: 8),
          TextField(
            controller: reasonController,
            maxLines: 2,
            decoration: _inputDecoration("e.g. Family Emergency"),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          _formLabel("Destination"),
          const SizedBox(height: 8),
          TextField(
            controller: destinationController,
            decoration: _inputDecoration("e.g. New Delhi"),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _formLabel("Leave Date"),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                leaveDate == null
                                    ? "dd-mm-yyyy"
                                    : "${leaveDate!.day}/${leaveDate!.month}/${leaveDate!.year}",
                                style: TextStyle(color: leaveDate == null ? Colors.grey : Colors.black87, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _formLabel("Duration"),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: durationController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                              ),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          Container(width: 1, height: 24, color: Colors.grey.shade200),
                          Expanded(
                            flex: 3,
                            child: DropdownButton<String>(
                              value: durationUnit,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: ["Hours", "Days"]
                                  .map((e) => DropdownMenuItem(value: e, child: Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(e, style: const TextStyle(fontSize: 12)),
                                  )))
                                  .toList(),
                              onChanged: (v) => setState(() => durationUnit = v!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _formLabel("Communication Language"),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _langOption("English"),
              _langOption("Hindi"),
              _langOption("Punjabi"),
            ],
          ),
          const SizedBox(height: 24),

          _formLabel("Select Parent Contact"),
          const SizedBox(height: 12),
          if (_profile != null && _profile!.parents.isNotEmpty && _profile!.parents.any((p) => p.phone.isNotEmpty))
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _profile!.parents
                  .where((p) => p.phone.isNotEmpty)
                  .map((p) => _parentOption(p))
                  .toList(),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "No contact numbers found in your profile. Please ask Warden to update your Parent info.",
                      style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isFormValid && !_isSubmitting
                  ? () async {
                      setState(() => _isSubmitting = true);
                      try {
                        final uid = await AuthService.getUid();
                        if (uid == null) throw Exception("User not logged in");
                        
                        final reqData = {
                          "student_id": uid,
                          "destination": destinationController.text,
                          "reason": reasonController.text,
                          "duration": "${durationController.text} $durationUnit",
                          "language": selectedLanguage,
                          "contact": selectedParent,
                          "leave_date": leaveDate != null
                              ? "${leaveDate!.year}-${leaveDate!.month.toString().padLeft(2, '0')}-${leaveDate!.day.toString().padLeft(2, '0')}"
                              : null,
                        };
                        
                        final repo = StudentRepository();
                        final res = await repo.submitLeaveRequest(reqData);
                        
                        if (res != null && res["status"] == "success" && res["req_id"] != null) {
                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => RequestStatusScreen(reqId: res["req_id"].toString())),
                            );
                          }
                        } else {
                          if (mounted) _showErrorDialog("Submission Failed", res?["error"] ?? res?["message"] ?? "Database Error");
                        }
                      } catch (e) {
                         if (mounted) _showErrorDialog("App Error", e.toString());
                      } finally {
                        if (mounted) setState(() => _isSubmitting = false);
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5AF0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSubmitting 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Submit Request", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formLabel(String label) {
    return Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4A4D55)));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D5AF0))),
    );
  }

  Widget _langOption(String lang) {
    bool isSelected = selectedLanguage == lang;
    return GestureDetector(
      onTap: () => setState(() => selectedLanguage = lang),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D5AF0).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF2D5AF0) : Colors.grey.shade200),
        ),
        child: Text(
          lang,
          style: TextStyle(color: isSelected ? const Color(0xFF2D5AF0) : Colors.grey.shade600, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12),
        ),
      ),
    );
  }

  Widget _parentOption(ParentContact parent) {
    bool isSelected = selectedParent == parent.phone;
    return GestureDetector(
      onTap: () => setState(() => selectedParent = parent.phone),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D5AF0).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF2D5AF0) : Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline_rounded, size: 16, color: isSelected ? const Color(0xFF2D5AF0) : Colors.grey),
            const SizedBox(width: 8),
            Text(
              "${parent.relation}: ${parent.phone}",
              style: TextStyle(color: isSelected ? const Color(0xFF2D5AF0) : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCooldownHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade100, shape: BoxShape.circle),
                child: const Icon(Icons.timer_off_rounded, color: Colors.redAccent, size: 20),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Submission Locked", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16)),
                  Text("Rejection Cooldown Active", style: TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Text(
              "Available in: ${_formatCooldown(_currentCooldownMs)}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Reason: ${_profile?.history.firstWhere((e) => e['Status'] == 'Rejected')['Reason'] ?? 'Violation of Rules'}",
            style: TextStyle(color: Colors.red.shade400, fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C21))),
            TextButton(onPressed: () {}, child: const Text("See All", style: TextStyle(color: Color(0xFF2D5AF0)))),
          ],
        ),
        const SizedBox(height: 12),
        ...(_profile!.history.map((h) => _buildHistoryItem(h)).toList()),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> h) {
    Color statusColor;
    IconData statusIcon;
    switch (h['Status']) {
      case 'Rejected':
        statusColor = Colors.redAccent;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'Entry':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Exit':
        statusColor = Colors.orange;
        statusIcon = Icons.directions_run_rounded;
        break;
      default:
        statusColor = const Color(0xFF2D5AF0);
        statusIcon = Icons.pending_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h['Destination'] ?? 'Campus Outing', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(h['leave_date'] ?? 'No date', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(h['Status'] ?? 'Unknown', style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
            const SizedBox(width: 12),
            const Text("Error", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            const Text("The system encountered a problem:"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.1)),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Understand"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5AF0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("Try Again"),
          ),
        ],
      ),
    );
  }
}