import 'package:flutter/material.dart';

class SnapshotError extends StatelessWidget {
  final AsyncSnapshot snapshot;
  final VoidCallback? refresh;
  const SnapshotError(this.snapshot, {super.key, this.refresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text('Error loading items', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: refresh, child: const Text('Retry')),
        ],
      ),
    );
  }
}
