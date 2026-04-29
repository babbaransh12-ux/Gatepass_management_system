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
      final rawStatus = item['Status'] ?? item['status'] ?? '';
      final lowerStatus = rawStatus.toString().toLowerCase();
      if (_selectedFilter == "Approved") {
        return lowerStatus.contains("approved") && !lowerStatus.contains("rejected");
      } else if (_selectedFilter == "Completed") {
        return lowerStatus == "exit" || lowerStatus == "entry" || lowerStatus == "completed";
      } else if (_selectedFilter == "Rejected") {
        return lowerStatus.contains("reject") || lowerStatus == "rejected";
      } else if (_selectedFilter == "Pending") {
        return lowerStatus == "pending";
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Request History", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A1628),
        elevation: 0,
        centerTitle: false,
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
    final filters = ["All", "Pending", "Approved", "Completed", "Rejected"];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: filters.map((f) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _filterChip(f),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _filterChip(String label) {
    bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A1628) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? const Color(0xFF0A1628) : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0A1628).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.3,
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: const Icon(Icons.history_rounded, size: 80, color: Color(0xFFE0E5EC)),
          ),
          const SizedBox(height: 24),
          const Text("No History Yet", style: TextStyle(color: Color(0xFF1A1C21), fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("When you make requests,\nthey will appear here.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final status = item['Status'] ?? item['status'] ?? 'Pending';
    final destination = item['Destination'] ?? 'Unknown Destination';
    final reason = item['Reason'] ?? 'No reason provided';
    final dateStr = item['created_at'] ?? DateTime.now().toIso8601String();
    final leaveDate = item['leave_date'] ?? item['Leave_date'] ?? item['date'] ?? 'N/A';
    
    DateTime dt;
    try {
       dt = DateTime.parse(dateStr.split('+')[0]);
    } catch(e) {
       dt = DateTime.now();
    }

    Color statusColor;
    Color bgColor;
    IconData statusIcon;
    String displayStatus = status.replaceAll('_', ' ');

    switch (status) {
      case 'Rejected':
      case 'Rejected_by_Parent':
      case 'Rejected_by_Warden':
        statusColor = const Color(0xFFE53935);
        bgColor = const Color(0xFFFFEBEE);
        statusIcon = Icons.cancel_rounded;
        break;
      case 'Deactivated':
        statusColor = Colors.grey.shade700;
        bgColor = Colors.grey.shade100;
        statusIcon = Icons.history_rounded;
        break;
      case 'Exit':
      case 'Entry':
        statusColor = const Color(0xFFF57C00);
        bgColor = const Color(0xFFFFF3E0);
        statusIcon = Icons.directions_run_rounded;
        break;
      case 'Approved':
      case 'Warden_Approved':
      case 'Parent_Approved':
        statusColor = const Color(0xFF43A047);
        bgColor = const Color(0xFFE8F5E9);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Completed':
        statusColor = const Color(0xFF00897B);
        bgColor = const Color(0xFFE0F2F1);
        statusIcon = Icons.done_all_rounded;
        break;
      default:
        statusColor = const Color(0xFF2D5AF0);
        bgColor = const Color(0xFFEDF1FF);
        statusIcon = Icons.pending_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {}, // For future detail view
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header with status and date
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: bgColor.withOpacity(0.5),
                    border: Border(
                      bottom: BorderSide(color: statusColor.withOpacity(0.1), width: 1),
                    )
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              displayStatus,
                              style: TextStyle(
                                color: statusColor, 
                                fontSize: 13, 
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, hh:mm a').format(dt),
                        style: TextStyle(
                          color: Colors.grey.shade600, 
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A1628).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.location_on_rounded, color: Color(0xFF0A1628), size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  destination,
                                  style: const TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.w800, 
                                    color: Color(0xFF1A1C21),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  reason,
                                  style: TextStyle(
                                    color: Colors.grey.shade600, 
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_note_rounded, size: 16, color: Colors.grey.shade500),
                            const SizedBox(width: 8),
                            Text(
                              "Leave Date:",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              leaveDate,
                              style: const TextStyle(
                                color: Color(0xFF1A1C21), 
                                fontSize: 14, 
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
