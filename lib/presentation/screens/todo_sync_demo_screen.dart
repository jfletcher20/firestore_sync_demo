import 'package:swan_sync/presentation/widgets/server_reachable_widget_refactored.dart';
import 'package:swan_sync/presentation/widgets/snapshot_error_widget.dart';
import 'package:swan_sync/presentation/widgets/synced_list_view.dart';
import 'package:swan_sync/presentation/widgets/no_items_widget.dart';
import 'package:swan_sync/communications/core/SWAN_sync.dart';
import 'package:swan_sync/example-data/models/todo_model.dart';
import 'package:swan_sync/data/i_syncable.dart';

import 'package:flutter/material.dart';

class TodoSyncDemoScreen extends StatefulWidget {
  const TodoSyncDemoScreen({super.key});

  @override
  State<TodoSyncDemoScreen> createState() => _TodoSyncDemoScreenState();
}

class _TodoSyncDemoScreenState extends State<TodoSyncDemoScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  static const String tableName = 'todos';

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
        title: const Text('SWAN Sync Demo (Refactored)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          _icbBuilder(Icons.sync, _syncPendingItems, 'Sync Pending Items'),
          _icbBuilder(Icons.refresh, _fullSyncTable, 'Full Sync Table'),
          _icbBuilder(Icons.sync_alt, _fullSyncAllTables, 'Full Sync All Tables'),
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
            FutureBuilder<List<ISyncable>>(
              future: SwanSync.syncController.getItems(tableName),
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                final pendingItems = items.where((item) => item.needsSync).length;
                return Row(
                  children: [
                    Icon(
                      pendingItems > 0 ? Icons.pending_actions : Icons.check_circle,
                      color: pendingItems > 0 ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$pendingItems Items Need Sync',
                      style: TextStyle(
                        color: pendingItems > 0 ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Registered Tables: ${SwanSync.syncController.getRegisteredTableNames().join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
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
            Text('Add New Todo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Enter todo name',
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
                        hintText: 'Enter todo description',
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
    return StreamBuilder<List<ISyncable>>(
      stream: SwanSync.syncController.watchTable(tableName),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SnapshotErrorWidget(snapshot: snapshot, retry: () => setState(() {}));
        }

        final items = snapshot.data ?? [];

        // if stream data is empty, load from local database;
        if (items.isEmpty) {
          return FutureBuilder<List<ISyncable>>(
            future: SwanSync.database.getAllItems(tableName),
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (futureSnapshot.hasError) {
                return SnapshotErrorWidget(snapshot: futureSnapshot, retry: () => setState(() {}));
              }

              final localItems = futureSnapshot.data ?? [];
              if (localItems.isEmpty) return const NoItemsWidget();

              final todoItems = localItems.cast<TodoModel>();
              return SyncedListView(items: todoItems, onUpdate: _updateItem, onDelete: _deleteItem);
            },
          );
        }

        final todoItems = items.cast<TodoModel>();
        return SyncedListView(items: todoItems, onUpdate: _updateItem, onDelete: _deleteItem);
      },
    );
  }

  Future<void> _addItem() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    if (name.isEmpty || description.isEmpty) return;

    return createSnackbarAfterFuture(
      () async {
        final newTodo = TodoModel.create(name: name, description: description);
        await SwanSync.syncController.createItem(newTodo);
        setState(() {
          _nameController.clear();
          _descriptionController.clear();
        });
      }(),
      'Todo added successfully',
      'Failed to add todo',
    );
  }

  Future<void> _updateItem(String uuid, String name, String description) async {
    return createSnackbarAfterFuture(
      () async {
        final existingItem = await SwanSync.syncController.getItem(tableName, uuid);
        if (existingItem is TodoModel) {
          final updatedTodo =
              existingItem.copyWith(
                    name: name,
                    description: description,
                    updatedAt: DateTime.now().toUtc(),
                  )
                  as TodoModel;
          await SwanSync.syncController.updateItem(updatedTodo);
        }
      }(),
      'Todo updated successfully',
      'Failed to update todo',
    );
  }

  Future<void> _deleteItem(String uuid) {
    return createSnackbarAfterFuture(
      SwanSync.syncController.deleteItem(tableName, uuid),
      'Todo deleted successfully',
      'Failed to delete todo',
    );
  }

  Future<void> _syncPendingItems() {
    return createSnackbarAfterFuture(
      SwanSync.syncController.syncPendingItems(tableName),
      'Sync completed',
      'Sync failed',
    );
  }

  Future<void> _fullSyncTable() {
    return createSnackbarAfterFuture(
      SwanSync.syncController.fullSyncTable(tableName),
      'Full table sync completed',
      'Full table sync failed',
    );
  }

  Future<void> _fullSyncAllTables() {
    return createSnackbarAfterFuture(
      SwanSync.syncController.fullSyncAllTables(),
      'Full sync of all tables completed',
      'Full sync failed',
    );
  }

  void snackbar(String s, {bool error = false}) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s), backgroundColor: error ? Colors.red : null));
    }
  }

  Future<void> createSnackbarAfterFuture(
    Future<void> future,
    String success,
    String failure,
  ) async {
    try {
      await future;
      setState(() => snackbar(success));
    } catch (e) {
      snackbar(failure, error: true);
    }
  }
}

IconButton _icbBuilder(IconData icon, VoidCallback onPressed, String? tooltip, {Color? color}) {
  return IconButton(icon: Icon(icon, color: color), onPressed: onPressed, tooltip: tooltip);
}
