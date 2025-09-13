import 'package:flutter/material.dart';

class SyncInitFailureWidget extends StatelessWidget {
  final AsyncSnapshot<void> snapshot;
  final VoidCallback retry;
  const SyncInitFailureWidget({super.key, required this.snapshot, required this.retry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text('Initialization Failed', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Error: ${snapshot.error}',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: retry, child: const Text('Retry')),
      ],
    );
  }
}
