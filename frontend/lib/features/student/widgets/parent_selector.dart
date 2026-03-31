import 'package:flutter/material.dart';

class ParentSelector extends StatelessWidget {

  final String selectedParent;
  final Function(String) onSelected;

  const ParentSelector({
    super.key,
    required this.selectedParent,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {

    final parents = [
      "Mr. Rajesh Sharma",
      "Mrs. Sunita Sharma",
      "Mr. Vikram Sharma"
    ];

    return Wrap(
      spacing: 10,
      children: parents.map((parent){

        return ChoiceChip(
          label: Text(parent),
          selected: selectedParent == parent,
          onSelected: (_) => onSelected(parent),
        );

      }).toList(),
    );
  }
}