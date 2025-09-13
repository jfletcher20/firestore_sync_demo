import 'package:flutter/material.dart';

class WaitingForStreamChangesWidget extends StatelessWidget {
  const WaitingForStreamChangesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Waiting for changes to items...'),
        ],
      ),
    );
  }
}
