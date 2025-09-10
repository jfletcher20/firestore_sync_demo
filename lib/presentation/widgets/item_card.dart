import 'package:flutter/material.dart';
import 'package:swan_sync/data/models/item_model.dart';
import 'package:swan_sync/presentation/widgets/item_info.dart';
import 'package:swan_sync/presentation/widgets/random_icon.dart';
import 'package:swan_sync/presentation/widgets/user_label.dart';

class ItemCard extends StatefulWidget {
  final ItemModel item;
  final VoidCallback onDelete;
  final Function(String) onUpdate;

  const ItemCard({super.key, required this.item, required this.onDelete, required this.onUpdate});

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
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
    return Stack(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isEditing) RandomIcon(randomFactor: widget.item.id),
                          if (_isEditing)
                            SizedBox(
                              width: MediaQuery.of(context).size.width * .5,
                              child: TextField(
                                controller: _controller,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onSubmitted: _saveEdit,
                                autofocus: true,
                              ),
                            )
                          else
                            InkWell(
                              onTap: () => setState(() => _isEditing = true),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                width: MediaQuery.of(context).size.width * .5,
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                child: Text(
                                  widget.item.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ItemInfo(label: 'ID', value: widget.item.id),
                      ItemInfo(label: 'Updated', value: _formatDate(widget.item.updatedAt)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ...controls,
              ],
            ),
          ),
        ),
        UserLabel(userId: widget.item.userId),
      ],
    );
  }

  List<Widget> get controls {
    return [
      if (_isEditing) ...[
        IconButton(
          onPressed: _saveEdit,
          icon: const Icon(Icons.check),
          tooltip: 'Save',
          color: Theme.of(context).colorScheme.primary,
        ),
        IconButton(onPressed: _cancelEdit, icon: const Icon(Icons.close), tooltip: 'Cancel'),
      ] else ...[
        IconButton(
          onPressed: () => setState(() => _isEditing = true),
          icon: const Icon(Icons.edit),
          tooltip: 'Edit',
        ),
        IconButton(
          onPressed: _confirmDelete,
          icon: const Icon(Icons.delete),
          tooltip: 'Delete',
          color: Theme.of(context).colorScheme.error,
        ),
      ],
    ];
  }

  void _saveEdit([String? value]) {
    final newName = value ?? _controller.text.trim();
    if (newName.isNotEmpty && newName != widget.item.name) {
      widget.onUpdate(newName);
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
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
