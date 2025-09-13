import 'package:flutter/material.dart';

class SnapshotErrorWidget extends StatelessWidget {
  final AsyncSnapshot<void> snapshot;
  final VoidCallback retry;
  const SnapshotErrorWidget({super.key, required this.snapshot, required this.retry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: ${snapshot.error}'),
          ElevatedButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
