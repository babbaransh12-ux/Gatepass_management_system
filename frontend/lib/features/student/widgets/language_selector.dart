import 'package:flutter/material.dart';

class LanguageSelector extends StatelessWidget {

  final String selectedLanguage;
  final Function(String) onSelected;

  const LanguageSelector({
    super.key,
    required this.selectedLanguage,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {

    final languages = ["English", "Hindi", "Punjabi"];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const Text(
          "Language for Parent Call",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 10),

        Wrap(
          spacing: 10,
          children: languages.map((lang) {

            return ChoiceChip(
              label: Text(lang),
              selected: selectedLanguage == lang,

              selectedColor: Colors.indigo.shade100,

              onSelected: (_) {
                onSelected(lang);
              },
            );

          }).toList(),
        ),

      ],
    );
  }
}