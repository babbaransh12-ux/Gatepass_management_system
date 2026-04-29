import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/navigation/logout_button.dart';
import '../../data/models/leave_request_model.dart';
import '../../data/repositories/warden_repository.dart';
import 'gate_log_history_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final WardenRepository repository = WardenRepository();
  Timer? _refreshTimer;

  int _selectedTabIndex = 0; // 0 for Today, 1 for Custom Date
  String _selectedFilter = 'All'; 

  int approvedToday = 0;
  int rejectedToday = 0;
  int activePasses = 0;
  int pendingReview = 0;
  int insideCampus = 0;
  int outsideCampus = 0;
  int totalCampus = 0;
  
  List<LeaveRequestModel> todayActivity = [];
  List<dynamic> liveGateLog = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    // We don't set _isLoading = true if we are just background refreshing, to avoid UI jumps
    if (todayActivity.isEmpty && liveGateLog.isEmpty) {
        setState(() => _isLoading = true);
    }
    
    try {
      final stats = await repository.fetchStats();
      
      final String todayDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final activity = await repository.fetchActivity(todayDateStr);
      final gateLogs = await repository.fetchGateLogs(todayDateStr);

      if (mounted) {
        setState(() {
          approvedToday = stats['approved_today'] ?? 0;
          rejectedToday = stats['rejected_today'] ?? 0;
          activePasses = stats['active_passes'] ?? 0;
          pendingReview = stats['pending_review'] ?? 0;
          insideCampus = stats['inside_campus'] ?? 0;
          outsideCampus = stats['outside_campus'] ?? 0;
          totalCampus = stats['total_students'] ?? 0;
          
          todayActivity = activity;
          liveGateLog = gateLogs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D5AF0)))
        : RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFF2D5AF0),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildSliverAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (_selectedTabIndex == 0) ...[
                        _buildDatePill(),
                        const SizedBox(height: 20),
                        _buildStatsGrid(),
                        const SizedBox(height: 20),
                        _buildCampusOccupancy(),
                        const SizedBox(height: 24),
                      ],
                      _buildViewGateLogHistoryButton(),
                      const SizedBox(height: 24),
                      _buildLiveGateLog(),
                      const SizedBox(height: 24),
                      _buildActivitySection(),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFF2D5AF0),
      pinned: true,
      elevation: 0,
      centerTitle: false,
      title: const Text(
        "Warden Reports",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: () => LogoutService.logout(context),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: _buildSegmentedControl(),
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 0),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Today",
                  style: TextStyle(
                    color: _selectedTabIndex == 0 ? const Color(0xFF1E3A8A) : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 1),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Custom Date",
                  style: TextStyle(
                    color: _selectedTabIndex == 1 ? const Color(0xFF1E3A8A) : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePill() {
    String formattedDate = DateFormat('EEE, d MMM yyyy').format(DateTime.now());
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF6B5BFB), 
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              "Today — $formattedDate",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.35,
      children: [
        _buildStatCard("Approved Today", approvedToday.toString(), Colors.green, Icons.check_circle_outline),
        _buildStatCard("Rejected Today", rejectedToday.toString(), Colors.redAccent, Icons.cancel_outlined),
        _buildStatCard("Active Passes", activePasses.toString(), Colors.blue, Icons.business_center_outlined),
        _buildStatCard("Pending Review", pendingReview.toString(), Colors.orange, Icons.assignment_outlined),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
          const Spacer(),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCampusOccupancy() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E56A0), 
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text("Campus Occupancy", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          _buildOccupancyItem("Inside", insideCampus.toString(), Icons.home_rounded, Colors.greenAccent),
          const SizedBox(width: 16),
          _buildOccupancyItem("Outside", outsideCampus.toString(), Icons.directions_walk_rounded, Colors.orangeAccent),
          const SizedBox(width: 16),
          _buildOccupancyItem("Total", totalCampus.toString(), Icons.groups_rounded, Colors.white),
        ],
      ),
    );
  }

  Widget _buildOccupancyItem(String label, String value, IconData icon, Color iconColor) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildViewGateLogHistoryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GateLogHistoryScreen())),
        icon: const Icon(Icons.receipt_long_rounded, size: 20),
        label: const Text("View Gate Log History", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A), 
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildLiveGateLog() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.sensors_rounded, color: Colors.blue, size: 18),
              ),
              const SizedBox(width: 12),
              const Text("Live Gate Log", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const Spacer(),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, color: Colors.blue, size: 20),
                visualDensity: VisualDensity.compact,
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GateLogHistoryScreen())),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text("See All", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (liveGateLog.isEmpty)
             const Center(child: Padding(padding: EdgeInsets.all(16), child: Text("No recent logs", style: TextStyle(color: Colors.grey))))
          else
             ...liveGateLog.take(5).map((log) => _buildLiveLogItem(log)),
        ],
      ),
    );
  }

  Widget _buildLiveLogItem(dynamic log) {
    final String rawAction = (log['Action'] ?? log['action'] ?? '').toString().toLowerCase();
    final bool isEntry = rawAction == 'entry';
    final Color actionColor = isEntry ? Colors.green : Colors.orange;
    final Color actionBg = isEntry ? Colors.green.shade50 : Colors.orange.shade50;
    
    final Map<String, dynamic> studentData = log['Student'] ?? {};
    final String studentName = (studentData['Name'] ?? log['student_name'] ?? 'Unknown').toString();
    final String studentId = (studentData['AU_id'] ?? log['student_id'] ?? '').toString();
    
    String timeStr = '';
    try {
       final dt = DateTime.parse(log['Timestamp'] ?? log['timestamp']);
       timeStr = DateFormat('hh:mm a').format(dt);
    } catch(e) {}
    
    final String imageUrl = (studentData['Student_image'] ?? log['student_image'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                Text(studentId, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Text(timeStr, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: actionBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: actionColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isEntry ? Icons.login_rounded : Icons.logout_rounded, color: actionColor, size: 12),
                const SizedBox(width: 4),
                Text(isEntry ? "IN" : "OUT", style: TextStyle(color: actionColor, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection() {
    List<LeaveRequestModel> filteredActivity = todayActivity;
    if (_selectedFilter == 'Approved') {
      filteredActivity = todayActivity.where((p) => p.status == 'Approved' || p.status == 'Completed' || p.status == 'Exit').toList();
    } else if (_selectedFilter == 'Rejected') {
      filteredActivity = todayActivity.where((p) => p.status == 'Rejected').toList();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 24, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 8),
            const Text("Today's Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
              child: Text("${filteredActivity.length} passes", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildFilterChip("All", Colors.blue),
            const SizedBox(width: 8),
            _buildFilterChip("Approved", Colors.green),
            const SizedBox(width: 8),
            _buildFilterChip("Rejected", Colors.red),
          ],
        ),
        const SizedBox(height: 16),
        if (filteredActivity.isEmpty)
           _buildEmptyActivity()
        else
           ...filteredActivity.map((pass) => _buildActivityCard(pass)),
      ],
    );
  }

  Widget _buildFilterChip(String label, Color color) {
    bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color.withOpacity(0.5) : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.insert_photo_rounded, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          const Text("No activity found", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)),
          Text("No passes processed today", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildActivityCard(LeaveRequestModel pass) {
    bool isRejected = pass.status == 'Rejected';
    Color statusColor = isRejected ? Colors.red : Colors.green;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.1),
            child: Icon(isRejected ? Icons.cancel_rounded : Icons.check_circle_rounded, color: statusColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pass.studentName, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(pass.studentId, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(pass.reason, style: TextStyle(fontSize: 13, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}