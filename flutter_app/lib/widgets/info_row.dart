import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: AppFontSize.body,
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
