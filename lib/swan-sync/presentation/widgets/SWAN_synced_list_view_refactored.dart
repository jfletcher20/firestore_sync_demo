import 'package:flutter/material.dart';
import 'package:swan_sync/swan-sync/data/models/todo_model.dart';
import 'package:swan_sync/swan-sync/presentation/widgets/SWAN_sync_item_card_refactored.dart';

class SWANSyncedListViewRefactored extends StatelessWidget {
  final List<TodoModel> items;
  final void Function(String uuid, String name, String description) onUpdate;
  final void Function(String uuid) onDelete;

  const SWANSyncedListViewRefactored({
    super.key,
    required this.items,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Sort items by update time (most recent first)
    final sortedItems = List<TodoModel>.from(items);
    sortedItems.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedItems.length,
      itemBuilder: (context, index) {
        final item = sortedItems[index];
        return SWANSyncItemCardRefactored(
          item: item,
          onUpdate: (name, description) => onUpdate(item.uuid, name, description),
          onDelete: () => onDelete(item.uuid),
        );
      },
    );
  }
}
