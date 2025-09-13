import 'package:flutter/material.dart';
import 'package:swan_sync/swan-sync/communications/services/sync_controller_refactored.dart';

class ServerReachableWidget extends StatelessWidget {
  const ServerReachableWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SyncController().isServerReachable(),
      builder: (context, snapshot) {
        final isReachable = snapshot.data ?? false;
        return Row(
          children: [
            Icon(
              isReachable ? Icons.cloud_done : Icons.cloud_off,
              color: isReachable ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              isReachable ? 'Server Connected' : 'Server Offline',
              style: TextStyle(
                color: isReachable ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}
