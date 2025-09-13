import 'package:flutter/material.dart';
import 'package:swan_sync/swan-sync/data/models/todo_model.dart';

class SWANSyncItemCardRefactored extends StatefulWidget {
  final TodoModel item;
  final Function(String, String) onUpdate;
  final VoidCallback onDelete;

  const SWANSyncItemCardRefactored({
    super.key,
    required this.item,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<SWANSyncItemCardRefactored> createState() => _SWANSyncItemCardRefactoredState();
}

class _SWANSyncItemCardRefactoredState extends State<SWANSyncItemCardRefactored> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _descriptionController = TextEditingController(text: widget.item.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
                            controller: _nameController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Name',
                            ),
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
                    onPressed: _saveEdit,
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
            if (_isEditing) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Description',
                ),
                maxLines: 2,
              ),
            ] else ...[
              const SizedBox(height: 8),
              _buildInfoRow('Description:', widget.item.description),
            ],
            const SizedBox(height: 8),
            _buildInfoRow('UUID:', widget.item.uuid),
            _buildInfoRow('OID:', widget.item.oid.toString()),
            if (widget.item.oid != -1) _buildInfoRow('Server ID:', widget.item.oid.toString()),
            _buildInfoRow('Table:', widget.item.tableName),
            _buildInfoRow('Created:', _formatDateTime(widget.item.createdAt)),
            _buildInfoRow('Updated:', _formatDateTime(widget.item.updatedAt)),
            const SizedBox(height: 8),
            Row(
              children: [
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
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Synced',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
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

  void _saveEdit() {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isNotEmpty &&
        description.isNotEmpty &&
        (name != widget.item.name || description != widget.item.description)) {
      widget.onUpdate(name, description);
    }
    setState(() => _isEditing = false);
  }

  void _cancelEdit() {
    _nameController.text = widget.item.name;
    _descriptionController.text = widget.item.description;
    setState(() => _isEditing = false);
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Todo'),
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
