import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/navigation/logout_button.dart';
import '../../data/models/leave_request_model.dart';
import '../../data/repositories/warden_repository.dart';
import 'active_passes_screen.dart';

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
  
  List<LeaveRequestModel> rejectedPasses = [];
  List<LeaveRequestModel> historyPasses = [];
  
  bool isLoadingStats = true;
  bool isLoadingRejected = true;
  bool isLoadingHistory = false;
  
  DateTime selectedDate = DateTime.now();
  String selectedGender = "All";
  String selectedDept = "All";
  
  int insideCampus = 0;
  int outsideCampus = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _fetchStats();
    _fetchRejected();
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await repository.fetchStats();
      setState(() {
        approvedToday = stats['approved_today'] ?? 0;
        rejectedToday = stats['rejected_today'] ?? 0;
        activePasses = stats['active_passes'] ?? 0;
        insideCampus = stats['inside_campus'] ?? 0;
        outsideCampus = stats['outside_campus'] ?? 0;
        isLoadingStats = false;
      });
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      setState(() => isLoadingStats = false);
    }
  }

  Future<void> _fetchRejected() async {
    try {
      final list = await repository.fetchRejectedList();
      setState(() {
        rejectedPasses = list;
        isLoadingRejected = false;
      });
    } catch (e) {
      debugPrint("Error fetching rejected: $e");
      setState(() => isLoadingRejected = false);
    }
  }

  Future<void> _fetchHistory(DateTime date) async {
    setState(() => isLoadingHistory = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final list = await repository.fetchHistory(dateStr);
      setState(() {
        historyPasses = list;
        isLoadingHistory = false;
      });
    } catch (e) {
      debugPrint("Error fetching history: $e");
      setState(() => isLoadingHistory = false);
    }
  }

  Future<void> _approveRejected(int index) async {
    final pass = rejectedPasses[index];
    try {
      await repository.approveRequest(pass.requestId);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pass approved successfully"))
        );
      }
      _loadData(); // Refresh everything
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Warden Reports"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: (){
              LogoutService.logout(context);
            },
          )
        ],),

      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live Tracking Row
              Row(
                children: [
                  _liveTrackingCard("Inside Campus", insideCampus.toString(), Colors.teal),
                  const SizedBox(width: 16),
                  _liveTrackingCard("Outside Campus", outsideCampus.toString(), Colors.orange),
                ],
              ),
              const SizedBox(height: 24),
              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatCard(title: "Approved Today", value: approvedToday.toString(), color: Colors.green),
                  StatCard(title: "Rejected Today", value: rejectedToday.toString(), color: Colors.red),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ActivePassesScreen()),
                      );
                    },
                    child: StatCard(title: "Active Passes", value: activePasses.toString(), color: Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // Filters
              _buildFilters(),
              const SizedBox(height: 30),
              
              // Rejected Section
              const Text("Recently Rejected (Undo?)", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (isLoadingRejected)
                const Center(child: CircularProgressIndicator())
              else if (rejectedPasses.isEmpty)
                const Text("No rejected passes found.")
              else
                _buildGroupedList(rejectedPasses),
                
              const SizedBox(height: 30),
              
              // History Section
              const Text("Custom Date Filter", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text("Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}")),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: const Text("Select Date"),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                        _fetchHistory(picked);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (isLoadingHistory)
                const Center(child: CircularProgressIndicator())
              else if (historyPasses.isEmpty && selectedDate.day != DateTime.now().day)
                 const Center(child: Text("No records for this date."))
              else
                _buildGroupedList(historyPasses),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedList(List<LeaveRequestModel> list) {
    // Basic filter logic
    final filtered = list.where((e) {
      bool g = selectedGender == "All" || e.gender == selectedGender;
      bool d = selectedDept == "All" || e.department == selectedDept;
      return g && d;
    }).toList();

    if (filtered.isEmpty) return const Text("No matches found with current filters.");

    // Simple grouping by Department
    Map<String, List<LeaveRequestModel>> grouped = {};
    for (var e in filtered) {
      String d = e.department ?? "General";
      grouped[d] = (grouped[d] ?? [])..add(e);
    }

    return Column(
      children: grouped.entries.map((group) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(group.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            ),
            ...group.value.map((pass) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(pass.studentImage),
                  radius: 18,
                ),
                title: Text(pass.studentName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text("To: ${pass.destination} | ${pass.status}"),
                trailing: Text(pass.gender ?? "", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            )).toList(),
          ],
        );
      }).toList(),
    );
  }

  Widget _liveTrackingCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: selectedGender,
            decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
            items: ["All", "Male", "Female"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => selectedGender = v!),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: selectedDept,
            decoration: const InputDecoration(labelText: "Dept", border: OutlineInputBorder()),
            items: ["All", "CS", "BTech", "BCA", "MTech"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => selectedDept = v!),
          ),
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {

  final String title;
  final String value;
  final Color color;

  const StatCard({super.key, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {

    return Expanded(
      child: Card(
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}