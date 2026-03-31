import 'package:flutter/material.dart';
import '../../data/repositories/warden_repository.dart';
import '../../data/api/api_client.dart';

class EditParentScreen extends StatefulWidget {
  final Map<String, String> student;

  const EditParentScreen({super.key, required this.student});

  @override
  State<EditParentScreen> createState() => _EditParentScreenState();
}

class _EditParentScreenState extends State<EditParentScreen> {
  final _formKey = GlobalKey<FormState>();
  final WardenRepository repository = WardenRepository();

  final TextEditingController fatherNameController = TextEditingController();
  final TextEditingController fatherPhoneController = TextEditingController();
  final TextEditingController motherNameController = TextEditingController();
  final TextEditingController motherPhoneController = TextEditingController();
  final TextEditingController guardianPhoneController = TextEditingController();

  bool _isSaving = false;
  bool _isLoading = true;
  String? studentImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchCurrentData();
  }

  Future<void> _fetchCurrentData() async {
    try {
      final res = await ApiClient.get("/student/profile/${widget.student['uid']}");
      if (res != null) {
        final parent = res['parent_info'] ?? {};
        setState(() {
          fatherNameController.text = parent['Father_Name'] ?? "";
          fatherPhoneController.text = parent['Father_Phone'] ?? "";
          motherNameController.text = parent['Mother_Name'] ?? "";
          motherPhoneController.text = parent['Mother_Phone'] ?? "";
          guardianPhoneController.text = parent['Guardian_Phone'] ?? "";
          studentImageUrl = res['profile_url']; // Backend key might be profile_url or Student_image
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to load student data: $e")));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      await repository.updateParentDetails(
        widget.student["uid"]!,
        {
          "father_name": fatherNameController.text.trim(),
          "father_phone": fatherPhoneController.text.trim(),
          "mother_name": motherNameController.text.trim(),
          "mother_phone": motherPhoneController.text.trim(),
          "guardian_phone": guardianPhoneController.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contact details updated successfully"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    fatherNameController.dispose();
    fatherPhoneController.dispose();
    motherNameController.dispose();
    motherPhoneController.dispose();
    guardianPhoneController.dispose();
    super.dispose();
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Manage Contacts", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student Profile Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.blue.shade50,
                          backgroundImage: studentImageUrl != null ? NetworkImage(studentImageUrl!) : null,
                          child: studentImageUrl == null ? const Icon(Icons.person, color: Colors.blueAccent) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.student['name']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text("AU ID: ${widget.student['uid']}", style: TextStyle(color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  _buildSectionHeader("Father's Details", Icons.face_rounded),
                  _buildField(fatherNameController, "Father's Name", Icons.person_outline),
                  _buildField(fatherPhoneController, "Father's Phone", Icons.phone_android_rounded, isPhone: true),

                  _buildSectionHeader("Mother's Details", Icons.face_3_rounded),
                  _buildField(motherNameController, "Mother's Name", Icons.person_outline),
                  _buildField(motherPhoneController, "Mother's Phone", Icons.phone_android_rounded, isPhone: true),

                  _buildSectionHeader("Other Contacts", Icons.security_rounded),
                  _buildField(guardianPhoneController, "Guardian's Phone", Icons.emergency_share_rounded, isPhone: true),

                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isSaving ? null : saveChanges,
                      child: _isSaving 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Update Database", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }
}
