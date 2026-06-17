import 'package:flutter/material.dart';

/// A two-column label:value row used in info / detail dialogs.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final double labelWidth;

  const InfoRow(
    this.label,
    this.value, {
    this.labelWidth = 80,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'),
            ),
          ),
        ],
      ),
    );
  }
}
