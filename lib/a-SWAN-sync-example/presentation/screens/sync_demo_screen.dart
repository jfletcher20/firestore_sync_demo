import 'package:swan_sync/a-SWAN-sync-example/presentation/widgets/server_reachable_widget.dart';
import 'package:swan_sync/a-SWAN-sync-example/presentation/widgets/SWAN_synced_list_view.dart';
import 'package:swan_sync/a-SWAN-sync-example/presentation/widgets/snapshot_error_widget.dart';
import 'package:swan_sync/a-SWAN-sync-example/communications/controllers/sync_controller.dart';
import 'package:swan_sync/a-SWAN-sync-example/presentation/widgets/no_items_widget.dart';
import 'package:swan_sync/a-SWAN-sync-example/models/sync_data_model.dart';

import 'package:flutter/material.dart';

class SyncDemoScreen extends StatefulWidget {
  const SyncDemoScreen({super.key});

  @override
  State<SyncDemoScreen> createState() => _SyncDemoScreenState();
}

class _SyncDemoScreenState extends State<SyncDemoScreen> {
  final SyncController _syncController = SyncController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  static const String tableName = 'testData';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          _icbBuilder(Icons.sync, _syncPendingItems, 'Sync Pending Items'),
          _icbBuilder(Icons.refresh, _processFallbackQueue, 'Process Fallback Queue'),
        ],
      ),
      body: Column(
        children: [_buildStatusCard(), _buildAddItemCard(), Expanded(child: _buildItemsList())],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sync Status', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const ServerReachableWidget(),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: _syncController.getPendingRequestCount(),
              builder: (context, snapshot) {
                final pendingCount = snapshot.data ?? 0;
                return Row(
                  children: [
                    Icon(
                      pendingCount > 0 ? Icons.pending_actions : Icons.check_circle,
                      color: pendingCount > 0 ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$pendingCount Pending Requests',
                      style: TextStyle(
                        color: pendingCount > 0 ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddItemCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add New Item', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Enter item name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        hintText: 'Enter item description',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addItem(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _addItem, child: const Text('Add')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return StreamBuilder<List<SyncDataModel>>(
      stream: _syncController.watchItems(tableName),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return SnapshotErrorWidget(snapshot: snapshot, retry: () => setState(() {}));
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const NoItemsWidget();
        return SWANSyncedListView(items: items, onUpdate: _update, onDelete: _delete);
      },
    );
  }

  Future<void> _addItem() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    if (name.isEmpty || description.isEmpty) return;
    return futureSnackbar(
      _syncController.createLocalItem(tableName, name, description).then((_) {
        setState(() {
          _nameController.clear();
          _descriptionController.clear();
        });
      }),
      'Item added successfully',
      'Failed to add item',
    );
  }

  Future<void> _update(String uuid, String name, String description) async {
    return futureSnackbar(
      _syncController.updateLocalItem(tableName, uuid, name, description),
      'Item updated successfully',
      'Failed to update item',
    );
  }

  Future<void> _delete(String uuid) {
    return futureSnackbar(
      _syncController.deleteLocalItem(tableName, uuid),
      'Item deleted successfully',
      'Failed to delete item',
    );
  }

  Future<void> _syncPendingItems() {
    return futureSnackbar(
      _syncController.syncPendingItems(tableName),
      'Sync completed',
      'Sync failed',
    );
  }

  Future<void> _processFallbackQueue() {
    return futureSnackbar(
      _syncController.processFallbackQueue(),
      'Fallback queue processed',
      'Fallback processing failed',
    );
  }

  void snackbar(String s, {bool error = false}) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s), backgroundColor: error ? Colors.red : null));
    }
  }

  Future<void> futureSnackbar(Future<void> future, String success, String failure) {
    try {
      return future.then((_) => setState(() => snackbar(success)));
    } catch (e) {
      snackbar(failure, error: true);
    }
    return Future.value();
  }
}

IconButton _icbBuilder(IconData icon, VoidCallback onPressed, String? tooltip, {Color? color}) {
  return IconButton(icon: Icon(icon, color: color), onPressed: onPressed, tooltip: tooltip);
}
