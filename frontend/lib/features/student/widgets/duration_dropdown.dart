import 'package:flutter/material.dart';

class DurationDropdown extends StatelessWidget {

  final String value;
  final Function(String) onChanged;

  const DurationDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {

    return DropdownButtonFormField(
      value: value,

      items: ["12","24","48","72"]
          .map((e) => DropdownMenuItem(
        value: e,
        child: Text("$e Hours"),
      ))
          .toList(),

      onChanged: (v) => onChanged(v!),

      decoration: const InputDecoration(
        labelText: "Duration",
        border: OutlineInputBorder(),
      ),
    );
  }
}