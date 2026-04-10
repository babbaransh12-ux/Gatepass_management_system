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
  
  int approvedToday = 0;
  int rejectedToday = 0;
  int activePasses = 0;
  int insideCampus = 0;
  int outsideCampus = 0;
  int pendingReview = 0;
  int totalStudents = 0;
  
  List<LeaveRequestModel> rejectedPasses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await repository.fetchStats();
      final rejected = await repository.fetchRejectedList();
      if (mounted) {
        setState(() {
          approvedToday = stats['approved_today'] ?? 0;
          rejectedToday = stats['rejected_today'] ?? 0;
          activePasses = stats['active_passes'] ?? 0;
          insideCampus = stats['inside_campus'] ?? 0;
          outsideCampus = stats['outside_campus'] ?? 0;
          pendingReview = stats['pending_review'] ?? 0;
          totalStudents = stats['total_students'] ?? 0;
          
          rejectedPasses = rejected;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _undoReject(LeaveRequestModel pass) async {
    try {
      // Re-approving a rejected pass is essentially "Undo Reject"
      await repository.approveRequest(pass.requestId.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rejection undone. Pass approved.")));
        _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Warden Reports", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
           Padding(
             padding: const EdgeInsets.only(right: 16.0),
             child: IconButton(
               icon: const Icon(Icons.logout_rounded, color: Color(0xFFF05A2D)),
               onPressed: () {
                 LogoutService.logout(context);
               },
             ),
           )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainStatsGrid(),
                  const SizedBox(height: 24),
                  _buildActiveTodaySection(),
                  const SizedBox(height: 24),
                  _buildNavHeader("Recently Rejected Passes", rejectedPasses.length),
                  const SizedBox(height: 12),
                  if (rejectedPasses.isEmpty)
                    _buildEmptyState("No recent rejections")
                  else
                    ...rejectedPasses.map((pass) => _buildRejectedCard(pass)).toList(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildMainStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _statBox("Inside Campus", insideCampus.toString(), Colors.teal, Icons.business_rounded),
        _statBox("Outside Campus", outsideCampus.toString(), Colors.orange, Icons.apartment_rounded),
        _statBox("Approved Today", approvedToday.toString(), Colors.green, Icons.check_circle_outline),
        _statBox("Rejected Today", rejectedToday.toString(), Colors.red, Icons.cancel_outlined),
      ],
    );
  }

  Widget _statBox(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTodaySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              const Text("Active Today", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _subStat("Active Passes", activePasses.toString(), Icons.description_outlined, Colors.blue),
              _subStat("Pending Review", pendingReview.toString(), Icons.access_time_rounded, Colors.purple),
              _subStat("Total Students", totalStudents.toString(), Icons.people_outline_rounded, Colors.indigo),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GateLogHistoryScreen())),
              icon: const Icon(Icons.list_alt_rounded, size: 20),
              label: const Text("View Gate Log History", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subStat(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildNavHeader(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
          child: Text("$count Rejected", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildRejectedCard(LeaveRequestModel pass) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(pass.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                      child: Text(pass.studentId, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text("Reason: ${pass.reason}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text("Just now", style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _undoReject(pass),
            icon: const Icon(Icons.undo_rounded, size: 14),
            label: const Text("Undo", style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, color: Colors.grey.shade300, size: 40),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}