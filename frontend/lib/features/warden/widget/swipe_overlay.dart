import 'package:flutter/material.dart';

class SwipeOverlay extends StatelessWidget {

  final bool isRight;

  const SwipeOverlay({super.key, required this.isRight});

  @override
  Widget build(BuildContext context) {

    return Positioned(
      top: 60,
      left: isRight ? null : 20,
      right: isRight ? 20 : null,

      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 25,
          vertical: 10,
        ),

        decoration: BoxDecoration(
          border: Border.all(
            color: isRight ? Colors.green : Colors.red,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(12),
        ),

        child: Text(
          isRight ? "APPROVE" : "REJECT",
          style: TextStyle(
            color: isRight ? Colors.green : Colors.red,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}