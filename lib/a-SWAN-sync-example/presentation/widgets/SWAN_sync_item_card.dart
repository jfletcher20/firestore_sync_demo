import 'package:flutter/material.dart';
import 'package:swan_sync/a-SWAN-sync-example/models/sync_data_model.dart';

class SWANSyncItemCard extends StatefulWidget {
  final SyncDataModel item;
  final Function(String) onUpdate;
  final VoidCallback onDelete;

  const SWANSyncItemCard({
    super.key,
    required this.item,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<SWANSyncItemCard> createState() => _SWANSyncItemCardState();
}

class _SWANSyncItemCardState extends State<SWANSyncItemCard> {
  bool _isEditing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.name);
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
                              widget.item.name,
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
            _buildInfoRow('Description:', widget.item.description),
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
    if (name.isNotEmpty && name != widget.item.name) {
      widget.onUpdate(name);
    }
    setState(() => _isEditing = false);
  }

  void _cancelEdit() {
    _controller.text = widget.item.name;
    setState(() => _isEditing = false);
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Item'),
            content: Text('Are you sure you want to delete "${widget.item.name}"?'),
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
