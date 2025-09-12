import 'package:flutter/material.dart';
import '../models/sync_data_model.dart';
import '../controllers/sync_controller.dart';

class SyncDemoScreen extends StatefulWidget {
  const SyncDemoScreen({super.key});

  @override
  State<SyncDemoScreen> createState() => _SyncDemoScreenState();
}

class _SyncDemoScreenState extends State<SyncDemoScreen> {
  final SyncController _syncController = SyncController();
  final TextEditingController _nameController = TextEditingController();
  static const String tableName = 'testData';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncPendingItems,
            tooltip: 'Sync Pending Items',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _processFallbackQueue,
            tooltip: 'Process Fallback Queue',
          ),
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
            FutureBuilder<bool>(
              future: _syncController.isServerReachable(),
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
            ),
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
                    onSubmitted: (_) => _addItem(),
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
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                ElevatedButton(onPressed: () => setState(() {}), child: const Text('Retry')),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No items yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                SizedBox(height: 8),
                Text('Add your first item above', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _ItemCard(
              item: item,
              onUpdate: (name) => _updateItem(item.uuid, name),
              onDelete: () => _deleteItem(item.uuid),
            );
          },
        );
      },
    );
  }

  Future<void> _addItem() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      await _syncController.createLocalItem(tableName, {'name': name});
      _nameController.clear();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item added successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add item: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateItem(String uuid, String name) async {
    try {
      await _syncController.updateLocalItem(tableName, uuid, {'name': name});

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item updated successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update item: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteItem(String uuid) async {
    try {
      await _syncController.deleteLocalItem(tableName, uuid);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item deleted successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete item: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _syncPendingItems() async {
    try {
      await _syncController.syncPendingItems(tableName);
      setState(() {}); // Refresh status

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync completed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _processFallbackQueue() async {
    try {
      await _syncController.processFallbackQueue();
      setState(() {}); // Refresh status

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Fallback queue processed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fallback processing failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _ItemCard extends StatefulWidget {
  final SyncDataModel item;
  final Function(String) onUpdate;
  final VoidCallback onDelete;

  const _ItemCard({required this.item, required this.onUpdate, required this.onDelete});

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  bool _isEditing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.data['name'] ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      _isEditing
                          ? TextField(
                            controller: _controller,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            onSubmitted: _saveEdit,
                          )
                          : GestureDetector(
                            onTap: () => setState(() => _isEditing = true),
                            child: Text(
                              widget.item.data['name'] ?? 'Unnamed',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                ),
                const SizedBox(width: 8),
                if (_isEditing) ...[
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _saveEdit(_controller.text),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: _cancelEdit),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => setState(() => _isEditing = true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _confirmDelete,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow('UUID:', widget.item.uuid),
            if (widget.item.entryId != null) _buildInfoRow('Server ID:', widget.item.entryId!),
            _buildInfoRow('Table:', widget.item.tableName),
            _buildInfoRow('Created:', _formatDateTime(widget.item.createdAt)),
            _buildInfoRow('Updated:', _formatDateTime(widget.item.updatedAt)),
            if (widget.item.needsSync)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Needs Sync',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontFamily: 'monospace'))),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _saveEdit(String value) {
    final name = value.trim();
    if (name.isNotEmpty && name != widget.item.data['name']) {
      widget.onUpdate(name);
    }
    setState(() => _isEditing = false);
  }

  void _cancelEdit() {
    _controller.text = widget.item.data['name'] ?? '';
    setState(() => _isEditing = false);
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Item'),
            content: Text('Are you sure you want to delete "${widget.item.data['name']}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    ).then((confirmed) {
      if (confirmed == true) {
        widget.onDelete();
      }
    });
  }
}
