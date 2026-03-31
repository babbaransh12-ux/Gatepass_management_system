import 'package:flutter/material.dart';

class LeaveForm extends StatelessWidget {

  final TextEditingController reasonController;
  final TextEditingController destinationController;

  final DateTime? leaveDate;
  final VoidCallback onPickDate;

  final String duration;
  final Function(String) onDurationChanged;

  const LeaveForm({
    super.key,
    required this.reasonController,
    required this.destinationController,
    required this.leaveDate,
    required this.onPickDate,
    required this.duration,
    required this.onDurationChanged,
  });

  @override
  Widget build(BuildContext context) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// Reason
        TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: "Reason for Leave",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.description),
          ),
        ),

        const SizedBox(height: 15),

        /// Destination
        TextField(
          controller: destinationController,
          decoration: const InputDecoration(
            labelText: "Destination",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
        ),

        const SizedBox(height: 15),

        /// Leave Date
        InkWell(
          onTap: onPickDate,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: "Leave Date",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),

            child: Text(
              leaveDate == null
                  ? "dd-mm-yyyy"
                  : "${leaveDate!.day}-${leaveDate!.month}-${leaveDate!.year}",
            ),
          ),
        ),

        const SizedBox(height: 15),

        /// Duration Dropdown
        DropdownButtonFormField(
          value: duration,

          items: ["12","24","48","72"]
              .map((e) => DropdownMenuItem(
            value: e,
            child: Text("$e Hours"),
          ))
              .toList(),

          onChanged: (value){
            onDurationChanged(value!);
          },

          decoration: const InputDecoration(
            labelText: "Duration (Hours)",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.access_time),
          ),
        ),

      ],
    );
  }
}