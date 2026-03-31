import 'package:flutter/material.dart';

class DatePickerField extends StatelessWidget {

  final DateTime? date;
  final Function() onTap;

  const DatePickerField({
    super.key,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return InkWell(
      onTap: onTap,

      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: "Leave Date",
          border: OutlineInputBorder(),
        ),

        child: Text(
          date == null
              ? "dd-mm-yyyy"
              : "${date!.day}-${date!.month}-${date!.year}",
        ),
      ),
    );
  }
}