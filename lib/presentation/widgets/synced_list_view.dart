import 'package:swan_sync/presentation/widgets/item_card.dart';
import 'package:swan_sync/data/models/item_model.dart';

import 'package:flutter/material.dart';

class SyncedListView extends StatelessWidget {
  final List<ItemModel> items;
  final Future<void> Function(String id, String name) onUpdate;
  final Future<void> Function(String id) onDelete;
  const SyncedListView({
    super.key,
    required this.items,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return ItemCard(
            item: item,
            onDelete: () => onDelete(item.id),
            onUpdate: (name) => onUpdate(item.id, name),
          );
        },
      ),
    );
  }
}
