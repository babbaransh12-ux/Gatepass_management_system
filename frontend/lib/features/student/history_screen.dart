import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/repositories/student_repository.dart';

class StudentHistoryScreen extends StatefulWidget {
  const StudentHistoryScreen({super.key});

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _history = [];
  String? _error;
  String _selectedFilter = "All"; // All, Completed, Rejected

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final uid = await AuthService.getUid();
      if (uid == null) throw Exception("User not logged in");
      
      final repo = StudentRepository();
      final profile = await repo.getStudentProfile(uid);
      
      if (mounted) {
        setState(() {
          _history = profile?.history ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _filteredHistory {
    if (_selectedFilter == "All") return _history;
    return _history.where((item) {
      final status = item['Status'] ?? '';
      if (_selectedFilter == "Approved") {
        return ["Approved", "Parent_Approved", "Warden_Approved"].contains(status);
      } else if (_selectedFilter == "Completed") {
        return ["Exit", "Entry", "Completed"].contains(status);
      } else if (_selectedFilter == "Rejected") {
        return ["Rejected", "Rejected_by_Parent", "Rejected_by_Warden"].contains(status);
      } else if (_selectedFilter == "Pending") {
        return ["Pending"].contains(status);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Request History", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchHistory,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text("Error: $_error"))
                      : _filteredHistory.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              itemCount: _filteredHistory.length,
                              itemBuilder: (context, index) {
                                final item = _filteredHistory[index];
                                return _buildHistoryCard(item);
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _filterChip("All"),
            const SizedBox(width: 8),
            _filterChip("Pending"),
            const SizedBox(width: 8),
            _filterChip("Approved"),
            const SizedBox(width: 8),
            _filterChip("Completed"),
            const SizedBox(width: 8),
            _filterChip("Rejected"),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label) {
    bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D5AF0) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No requests found", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final status = item['Status'] ?? 'Pending';
    final destination = item['Destination'] ?? 'Unknown';
    final reason = item['Reason'] ?? 'No reason provided';
    final dateStr = item['created_at'] ?? DateTime.now().toIso8601String();
    
    DateTime? dt;
    try {
       dt = DateTime.parse(dateStr.split('+')[0]);
    } catch(e) {
       dt = DateTime.now();
    }

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Rejected':
      case 'Rejected_by_Parent':
      case 'Rejected_by_Warden':
        statusColor = Colors.redAccent;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'Deactivated':
        statusColor = Colors.grey;
        statusIcon = Icons.history_rounded;
        break;
      case 'Exit':
      case 'Entry':
        statusColor = Colors.orange;
        statusIcon = Icons.directions_run_rounded;
        break;
      case 'Approved':
      case 'Warden_Approved':
      case 'Parent_Approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Completed':
        statusColor = Colors.teal;
        statusIcon = Icons.done_all_rounded;
        break;
      default:
        statusColor = const Color(0xFF2D5AF0);
        statusIcon = Icons.pending_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      status.replaceAll('_', ' '),
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(dt!),
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            destination,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1C21)),
          ),
          const SizedBox(height: 4),
          Text(
            reason,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(height: 24),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(
                item['Leave_date'] ?? 'N/A',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }
}
