import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = '重试',
    this.icon,
    this.details,
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData? icon;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? Icons.error_outline,
            size: 40,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: AppFontSize.body,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (details != null && details!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                details!,
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(retryLabel),
            ),
          ],
        ],
      ),
    );
  }
}
