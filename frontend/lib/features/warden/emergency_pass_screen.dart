import 'package:flutter/material.dart';
import '../../core/navigation/logout_button.dart';
import '../../data/api/api_client.dart';

class EmergencyPassScreen extends StatelessWidget {

  final Map<String,String> student;

  const EmergencyPassScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final reasonCtrl = TextEditingController();

    return Scaffold(

      appBar: AppBar(title: const Text("Emergency Pass"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: (){
              LogoutService.logout(context);
            },
          )
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(

          children: [

            Text(
              student["name"]!,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            Text(student["uid"]!),

            const SizedBox(height: 20),

            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: "Reason",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Generate Emergency Pass", style: TextStyle(color: Colors.white)),
              onPressed: () async {
                try {
                  final res = await ApiClient.post("/warden/emergency-pass", {
                    "student_id": student["uid"],
                    "reason": reasonCtrl.text.isEmpty ? "Emergency override" : reasonCtrl.text,
                    "destination": "Emergency Exit"
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res["message"])));
                    Navigator.pop(context);
                  }
                } catch(e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
            )

          ],
        ),
      ),
    );
  }
}