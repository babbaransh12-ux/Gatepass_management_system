import 'package:flutter/material.dart';

class RequestLeaveScreen extends StatefulWidget {
  const RequestLeaveScreen({super.key});

  @override
  State<RequestLeaveScreen> createState() => _RequestLeaveScreenState();
}

class _RequestLeaveScreenState extends State<RequestLeaveScreen> {

  bool hasProfileImage = false;

  final reasonController = TextEditingController();
  final destinationController = TextEditingController();

  void submitRequest(){

    if(!hasProfileImage){

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Upload profile photo first"),
        ),
      );

      return;
    }

    /// send to FastAPI

    debugPrint("Leave request submitted");

  }

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.all(20),

      child: Column(

        children: [

          TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: "Reason",
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: destinationController,
            decoration: const InputDecoration(
              labelText: "Destination",
            ),
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: submitRequest,
            child: const Text("Submit Leave Request"),
          )

        ],
      ),
    );
  }
}