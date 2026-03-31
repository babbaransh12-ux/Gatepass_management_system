import 'package:flutter/material.dart';
import '../../data/models/leave_request_model.dart';
import '../../data/repositories/warden_repository.dart';

class ActivePassesScreen extends StatefulWidget {
  const ActivePassesScreen({super.key});

  @override
  State<ActivePassesScreen> createState() => _ActivePassesScreenState();
}

class _ActivePassesScreenState extends State<ActivePassesScreen> {
  final WardenRepository repository = WardenRepository();
  List<LeaveRequestModel> activePasses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivePasses();
  }

  Future<void> _loadActivePasses() async {
    try {
      final passes = await repository.fetchActivePasses();
      setState(() {
        activePasses = passes;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading active passes: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Active Passes"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : activePasses.isEmpty
              ? const Center(child: Text("No active passes currently."))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: activePasses.length,
                  itemBuilder: (context, index) {
                    final pass = activePasses[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.network(
                                pass.studentImage.isNotEmpty ? pass.studentImage : "https://via.placeholder.com/100",
                                width: 85,
                                height: 85,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => const Icon(Icons.person, size: 40, color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pass.studentName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1C1E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "To: ${pass.destination}",
                                  style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2D5AF0), fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.access_time_filled_rounded, size: 14, color: Colors.orange.shade400),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        "Expires: ${pass.date}",
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
