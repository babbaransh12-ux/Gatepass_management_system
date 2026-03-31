import 'package:flutter/material.dart';
import '../../core/navigation/logout_button.dart';
import '../../data/api/api_client.dart';
import 'edit_parent_screen.dart';
import 'emergency_pass_screen.dart';

class SearchStudentScreen extends StatefulWidget {
  const SearchStudentScreen({super.key});

  @override
  State<SearchStudentScreen> createState() => _SearchStudentScreenState();
}

class _SearchStudentScreenState extends State<SearchStudentScreen> {
  final TextEditingController searchController = TextEditingController();
  List<dynamic> results = [];
  bool _isLoading = false;

  Future<void> performSearch() async {
    final query = searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Using the new advanced search endpoint
      final data = await ApiClient.get("/warden/search?query=$query");
      setState(() {
        results = data ?? [];
      });
      if (results.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No students found matching your search")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Search failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Student Directory", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => LogoutService.logout(context),
          )
        ],
      ),
      body: Column(
        children: [
          // Premium Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                onSubmitted: (_) => performSearch(),
                decoration: InputDecoration(
                  hintText: "Search by Name, Room, or AU ID...",
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.blueAccent),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.blueAccent),
                    onPressed: performSearch,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ),

          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator())),

          if (!_isLoading && results.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_search_rounded, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text("Search students to manage data", style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
            ),

          if (!_isLoading && results.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final s = results[index];
                  final parent = s['parent_info'] ?? {};
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Circular Profile Photo
                              Hero(
                                tag: "profile_${s['AU_id']}",
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 2),
                                  ),
                                  child: CircleAvatar(
                                    radius: 35,
                                    backgroundColor: Colors.blue.shade50,
                                    backgroundImage: s['Student_image'] != null 
                                      ? NetworkImage(s['Student_image']) 
                                      : null,
                                    child: s['Student_image'] == null 
                                      ? const Icon(Icons.person, size: 35, color: Colors.blueAccent)
                                      : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s['Name'] ?? "N/A",
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Room: ${s['Room_no'] ?? 'N/A'} | ${s['Course'] ?? 'N/A'}",
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "AU ID: ${s['AU_id']}",
                                      style: TextStyle(color: Colors.blueAccent.shade700, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          // Parent Info Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Father: ${parent['Father_Name'] ?? 'Not Set'}", 
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  Text("Mother: ${parent['Mother_Name'] ?? 'Not Set'}", 
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.settings_suggest_rounded, color: Colors.blueAccent),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditParentScreen(student: {
                                        "name": s['Name']?.toString() ?? "",
                                        "uid": s['AU_id']?.toString() ?? "",
                                      }),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text("Reset Device"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange.shade700,
                                    side: BorderSide(color: Colors.orange.shade200),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => _showResetConfirm(s['AU_id']?.toString()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.emergency_rounded, size: 18),
                                  label: const Text("Emergency"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EmergencyPassScreen(student: {
                                          "name": s['Name']?.toString() ?? "",
                                          "uid": s['AU_id']?.toString() ?? "",
                                        }),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showResetConfirm(String? uid) {
    if (uid == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset Device binding?"),
        content: Text("This will allow student $uid to login from a new device. Continue?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final res = await ApiClient.post("/warden/reset-device/$uid", {});
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res["message"] ?? "Success")));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Confirm Reset"),
          ),
        ],
      ),
    );
  }
}