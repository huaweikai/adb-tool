import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: TextStyle(
                fontSize: AppFontSize.body,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
