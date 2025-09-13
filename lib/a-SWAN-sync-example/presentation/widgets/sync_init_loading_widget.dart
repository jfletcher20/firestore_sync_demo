import 'package:flutter/material.dart';

class SyncInitLoadingWidget extends StatelessWidget {
  const SyncInitLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.sync, size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'Swan Sync',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Initializing sync framework...',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        const CircularProgressIndicator(),
      ],
    );
  }
}
