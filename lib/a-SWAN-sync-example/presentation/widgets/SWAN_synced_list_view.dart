import 'package:flutter/material.dart';
import 'package:swan_sync/a-SWAN-sync-example/models/sync_data_model.dart';
import 'package:swan_sync/a-SWAN-sync-example/presentation/widgets/SWAN_sync_item_card.dart';

class SWANSyncedListView extends StatelessWidget {
  final List<SyncDataModel>? items;
  final void Function(String uuid, String name, String description) onUpdate;
  final void Function(String uuid) onDelete;

  const SWANSyncedListView({
    super.key,
    required this.items,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    items?.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items?.length ?? 0,
      itemBuilder: (context, index) {
        final item = items![index];
        return SWANSyncItemCard(
          item: item,
          onUpdate: (name) => onUpdate(item.uuid, name, item.description),
          onDelete: () => onDelete(item.uuid),
        );
      },
    );
  }
}
