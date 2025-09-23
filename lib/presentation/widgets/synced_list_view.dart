import 'package:flutter/material.dart';
import 'package:swan_sync_demo/example-data/models/todo_model.dart';
import 'package:swan_sync_demo/presentation/widgets/todo_item_card.dart';

class SyncedListView extends StatelessWidget {
  final List<TodoModel> items;
  final void Function(String uuid, String name, String description) onUpdate;
  final void Function(String uuid) onDelete;

  const SyncedListView({
    super.key,
    required this.items,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sortedItems = [...items]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedItems.length,
      itemBuilder: (context, index) {
        final item = sortedItems[index];
        return TodoItemCard(
          item: item,
          onUpdate: (name, description) => onUpdate(item.uuid, name, description),
          onDelete: () => onDelete(item.uuid),
        );
      },
    );
  }
}
