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
              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatCard(title: "Approved", value: approvedToday.toString(), color: Colors.green),
                  StatCard(title: "Rejected", value: rejectedToday.toString(), color: Colors.red),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ActivePassesScreen()),
                      );
                    },
                    child: StatCard(title: "Active", value: activePasses.toString(), color: Colors.blue),
                  ),
                ],
              ),
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
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rejectedPasses.length,
                  itemBuilder: (context, index) {
                    final pass = rejectedPasses[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline, color: Colors.red),
                        title: Text(pass.studentName),
                        subtitle: Text("To: ${pass.destination}"),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, 
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(8)
                          ),
                          onPressed: () => _approveRejected(index),
                          child: const Text("Approve"),
                        ),
                      ),
                    );
                  },
                ),
                
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
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: historyPasses.length,
                  itemBuilder: (context, index) {
                    final pass = historyPasses[index];
                    final isApproved = pass.status == "Approved";
                    return ListTile(
                      leading: Icon(isApproved ? Icons.check_circle : Icons.cancel, 
                        color: isApproved ? Colors.green : Colors.red),
                      title: Text(pass.studentName),
                      subtitle: Text("Status: ${pass.status} | To: ${pass.destination}"),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
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