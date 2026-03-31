import 'package:flutter/material.dart';

class SubmitLeaveButton extends StatelessWidget {

  final bool enabled;
  final VoidCallback onPressed;

  const SubmitLeaveButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      width: double.infinity,

      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,

        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(15),
          backgroundColor: Colors.indigo,
        ),

        child: const Text("Submit Leave Request"),
      ),
    );
  }
}