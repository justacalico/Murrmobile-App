import 'package:flutter/material.dart';

class ErrorState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.icon = Icons.error_outline,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 15),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
