import 'package:flutter/material.dart';

class ActiveGatepassCard extends StatelessWidget {

  final String destination;
  final String date;
  final String duration;

  const ActiveGatepassCard({
    super.key,
    required this.destination,
    required this.date,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {

    return Card(
      child: ListTile(

        leading: const Icon(Icons.qr_code),

        title: Text(destination),

        subtitle: Text("$date • $duration"),

        trailing: const Icon(Icons.arrow_forward_ios),

      ),
    );
  }
}